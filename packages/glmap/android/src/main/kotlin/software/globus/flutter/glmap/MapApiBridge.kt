package software.globus.flutter.glmap

import android.graphics.PointF
import android.os.Handler
import android.os.Looper
import globus.glmap.GLMapTextureView
import globus.glmap.MapGeoPoint
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine

/** Owns Flutter replies; GLMapTextureView retains responsibility for native rendering. */
internal class MapApiBridge(
    map: GLMapTextureView,
    private val messenger: BinaryMessenger,
    id: Int,
) : MapHostApi {
    private var map: GLMapTextureView? = map
    private val suffix = id.toString()
    private val main = Handler(Looper.getMainLooper())
    // Accessed only on main, including native callbacks marshalled from the render thread.
    private val captures = mutableSetOf<CancellableContinuation<MapStateMessage>>()
    private var nextLayer = 0L
    private val layers = mutableMapOf<Long, VectorLayerBridge>()
    private val creations = mutableMapOf<Long, (Result<Long>) -> Unit>()

    private var taps = 0
    private var moves = 0

    init { MapHostApi.setUp(messenger, this, suffix) }

    fun recordTap() { if (map != null) taps++ }
    fun recordMove() { if (map != null) moves++ }

    override fun diagnostics(): Map<String, Any?> {
        val view = map ?: throw MapApiError("map_disposed", "The map has been removed")
        val center = view.renderer.mapGeoCenter
        return mapOf("latitude" to center.lat, "longitude" to center.lon,
            "zoom" to view.renderer.mapZoom, "angle" to view.renderer.mapAngle,
            "taps" to taps, "moves" to moves, "width" to view.width, "height" to view.height,
            "surfaceAvailable" to view.isAvailable, "initializationResult" to true,
            "sdk" to "GLMap", "vectorLayers" to vectorDiagnostics())
    }

    private fun activeMap(): GLMapTextureView {
        val view = map ?: throw MapApiError("map_disposed", "The map has been removed")
        if (!view.isAvailable || view.renderer.surfaceWidth <= 0 || view.renderer.surfaceHeight <= 0)
            throw MapApiError("map_unavailable", "The map is not attached to a surface")
        return view
    }

    override suspend fun captureState(): MapStateMessage {
        val view = activeMap()
        return suspendCancellableCoroutine { reply ->
            captures.add(reply)
            view.renderer.captureState { state ->
                val value = runCatching {
                    state.use {
                        val center = it.getGeoCenter(MapGeoPoint())
                        val origin = it.getOrigin(PointF())
                        MapStateMessage(center.lat, center.lon, it.zoom, it.scale,
                            it.angle.toDouble(), it.pitch.toDouble(), origin.x.toDouble(), origin.y.toDouble())
                    }
                }
                main.post {
                    if (captures.remove(reply) && reply.isActive) reply.resumeWith(value)
                }
            }
        }
    }

    override fun setCamera(camera: MapCameraMessage) {
        val view = activeMap()
        if (!listOf(camera.latitude, camera.longitude, camera.zoom, camera.angle, camera.pitch).all { it.isFinite() }
            || camera.latitude !in -90.0..90.0 || camera.longitude !in -180.0..180.0
            || camera.pitch !in 0.0..45.0 || !camera.angle.toFloat().isFinite())
            throw MapApiError("invalid_argument", "Invalid camera coordinates or angles")
        view.renderer.setMapGeoCenterLatLon(camera.latitude, camera.longitude)
        view.renderer.mapZoom = camera.zoom
        view.renderer.mapAngle = camera.angle.toFloat()
        view.renderer.mapPitch = camera.pitch.toFloat()
    }

    override fun createVectorLayer(drawOrder: Long, callback: (Result<Long>) -> Unit) {
        try {
            val view = map ?: throw MapApiError("map_disposed", "The map has been removed")
            if (drawOrder !in Int.MIN_VALUE.toLong()..Int.MAX_VALUE.toLong())
                throw MapApiError("invalid_argument", "drawOrder must fit int32")
            val entry = VectorLayerBridge(drawOrder.toInt())
            val id = ++nextLayer
            layers[id] = entry
            creations[id] = callback
            view.renderer.add(entry.layer)
            // Same native map queue as add. Do not expose the handle while the
            // layer is detached: its setters otherwise run inline on the caller.
            view.renderer.doWhenSurfaceCreated {
                main.post { creations.remove(id)?.invoke(Result.success(id)) }
            }
        } catch (error: Exception) { callback(Result.failure(error)) }
    }

    override fun mutateVectorLayer(mutation: VectorMutationMessage, callback: (Result<VectorReply>) -> Unit) {
        try {
            val view = map ?: throw MapApiError("map_disposed", "The map has been removed")
            val entry = layers[mutation.layerId] ?: throw MapApiError("layer_removed", "Unknown or removed layer")
            if (mutation.operation == VectorMutation.REMOVE) {
                layers.remove(mutation.layerId)
                view.renderer.remove(entry.layer)
                entry.close()
                callback(Result.success(VectorReply.REMOVED))
            } else entry.update(mutation, callback)
        } catch (error: Exception) { callback(Result.failure(error)) }
    }

    override fun pickVectorFeature(layerId: Long, x: Double, y: Double, tolerance: Double, callback: (Result<String?>) -> Unit) {
        callback(runCatching {
            require(x.isFinite() && y.isFinite() && tolerance.isFinite() && tolerance >= 0)
            val layer = layers[layerId] ?: throw MapApiError("layer_removed", "Unknown or removed layer")
            layer.pick(activeMap(), x, y, tolerance)
        })
    }

    fun vectorDiagnostics(): List<Map<String, Any>> = layers.map { it.value.diagnostics(it.key) }

    override fun dispose() {
        val creating = creations.values.toList()
        creations.clear()
        creating.forEach { it(Result.failure(MapApiError("map_disposed", "The map has been removed"))) }
        layers.values.forEach { map?.renderer?.remove(it.layer); it.close() }
        layers.clear()
        map = null
        val waiting = captures.toList()
        captures.clear()
        waiting.forEach {
            if (it.isActive) it.resumeWith(Result.failure(MapApiError("map_disposed", "The map has been removed")))
        }
        MapHostApi.setUp(messenger, null, suffix)
    }
}
