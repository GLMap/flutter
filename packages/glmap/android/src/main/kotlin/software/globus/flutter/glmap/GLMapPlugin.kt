package software.globus.flutter.glmap

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.SurfaceTexture
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.view.TextureView
import globus.glmap.*
import software.globus.flutter.core.CoreResources
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class GLMapPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory("software.globus.glmap/view", Factory(binding.binaryMessenger, MapAssets(binding.applicationContext, binding.flutterAssets)))
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}

    private class Factory(private val messenger: BinaryMessenger, private val sdk: MapAssets) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
            MapPlatformView(context, viewId, messenger, args as Map<*, *>, sdk)
    }
}

private class MapPlatformView(context: Context, private val id: Int, messenger: BinaryMessenger, fixture: Map<*, *>, sdk: MapAssets) : PlatformView {
    private val resources = CoreResources.forMessenger(messenger)
    private val map: GLMapTextureView
    private val track: GLMapVectorLayer
    private val marker: GLMapImage
    private var disposed = false
    private val api: MapApiBridge
    private val features: MapFeaturesBridge

    init {
        // Explicit fixture creation remains supported for controlled integration tests.
        if (fixture.containsKey("trackJson")) {
            check(GLMapManager.Initialize(context.applicationContext, "", null)) { "GLMap initialization failed" }
        }
        map = GLMapTextureView(context)
        // Texture composition needs invalidation even while the map is stationary.
        map.surfaceTextureListener = object : TextureView.SurfaceTextureListener by map.renderer {
            override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {
                map.renderer.onSurfaceTextureUpdated(surface)
                map.invalidate()
            }
        }
        map.contentDescription = "GLMap canvas"
        map.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        track = GLMapVectorLayer(1)
        marker = GLMapImage(2)
        setCamera(fixture["camera"] as Map<*, *>)
        val objects = GLMapVectorObject.createFromGeoJSONOrThrow((fixture["trackJson"] as? String ?: "{\"type\":\"FeatureCollection\",\"features\":[]}"))
        val style = checkNotNull(GLMapVectorCascadeStyle.createStyle("line{width:4pt;color:#E74C3C;}"))
        track.setVectorObjects(objects, style, null)
        map.renderer.add(track)

        val point = fixture["marker"] as? Map<*, *> ?: mapOf("latitude" to 0, "longitude" to 0)
        val diameter = (24 * context.resources.displayMetrics.density).toInt()
        val bitmap = Bitmap.createBitmap(diameter, diameter, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = Color.WHITE
        canvas.drawCircle(diameter / 2f, diameter / 2f, diameter / 2f, paint)
        paint.color = Color.rgb(38, 80, 214)
        canvas.drawCircle(diameter / 2f, diameter / 2f, diameter * .36f, paint)
        marker.setBitmap(bitmap)
        marker.setOffset(diameter / 2, diameter / 2)
        marker.position = MapPoint.CreateFromGeoCoordinates(point.number("latitude"), point.number("longitude"))
        if (fixture.containsKey("marker")) map.renderer.add(marker)
        api = MapApiBridge(map, messenger, id)
        features = MapFeaturesBridge(map, sdk, resources, messenger, id)
        resources.registerMap(id, context.resources.displayMetrics.density.toDouble()) { reply ->
            if (!map.isAvailable || disposed) reply(Result.failure(IllegalStateException("map_unavailable")))
            else map.renderer.captureState { reply(Result.success(it)) }
        }
        val detector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
            override fun onDown(e: MotionEvent) = true
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean { api.recordTap(); features.tap(e.x, e.y, false); return true }
            override fun onLongPress(e: MotionEvent) { features.tap(e.x, e.y, true) }
        })
        map.setOnTouchListener { _, event -> detector.onTouchEvent(event); false }
        map.renderer.setMapDidMoveCallback { map.post { if (!disposed) api.recordMove() } }
    }

    private fun setCamera(camera: Map<*, *>) {
        map.renderer.setMapGeoCenterLatLon(camera.number("latitude"), camera.number("longitude"))
        map.renderer.mapZoom = camera.number("zoom")
        map.renderer.mapAngle = 0f
    }
    override fun getView(): View = map
    override fun dispose() {
        if (disposed) return
        disposed = true
        resources.unregisterMap(id)
        features.dispose()
        api.dispose()
        map.setOnTouchListener(null)
        map.renderer.remove(marker)
        map.renderer.remove(track)
        map.dispose()
        marker.dispose()
        track.dispose()
    }
}

private fun Map<*, *>.number(key: String) = (get(key) as Number).toDouble()
