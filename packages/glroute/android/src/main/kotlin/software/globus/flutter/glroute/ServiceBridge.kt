package software.globus.flutter.glroute

import android.content.Context
import android.os.Handler
import android.os.Looper
import globus.glmap.*
import software.globus.flutter.core.CoreResources
import software.globus.flutter.core.NativeTrackSource
import kotlinx.coroutines.*
import globus.glroute.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import java.io.File

internal fun GeoMessage.native() = MapGeoPoint(latitude, longitude)
internal fun MapGeoPoint.message() = GeoMessage(lat, lon)
internal fun BoundsMessage.native() = GLMapBBox().apply {
    addPoint(MapPoint.CreateFromGeoCoordinates(south, west)); addPoint(MapPoint.CreateFromGeoCoordinates(north, east))
}
internal fun GLMapBBox.message(): BoundsMessage {
    val a = MapGeoPoint(MapPoint(origin_x, origin_y))
    val b = MapGeoPoint(MapPoint(origin_x + size_x, origin_y + size_y))
    return BoundsMessage(minOf(a.lat,b.lat),minOf(a.lon,b.lon),maxOf(a.lat,b.lat),maxOf(a.lon,b.lon))
}
internal fun featureError(error: Any) = FeatureError("sdk_error", error.toString())

internal class ServiceBridge(private val messenger: BinaryMessenger) : RouteHostApi {
    private val main = Handler(Looper.getMainLooper())
    private var attached = true
    private val cancels = mutableMapOf<Long, () -> Unit>()
    private val resources = CoreResources.forMessenger(messenger)
    val routes = mutableMapOf<Long, GLRoute>()
    private val trackers = mutableMapOf<Long, GLRouteTracker>()
    init { RouteHostApi.setUp(messenger,this) }
    override fun route(requestId: Long, start: GeoMessage, end: GeoMessage, mode: String, offline: Boolean, offlineConfig: String?, callback: (Result<RouteMessage>) -> Unit) {
        val request = GLRouteRequest().apply {
            when (mode) {
                "car" -> setAutoWithOptions(CostingOptions.Auto())
                "bicycle" -> setBicycleWithOptions(CostingOptions.Bicycle())
                "pedestrian" -> setPedestrianWithOptions(CostingOptions.Pedestrian())
                else -> throw FeatureError("invalid_argument", "Unknown route mode")
            }
            locale = "en-US"
            addPoint(GLRoutePoint(start.native(), Double.NaN, GLRoutePoint.Type.BREAK))
            addPoint(GLRoutePoint(end.native(), Double.NaN, GLRoutePoint.Type.BREAK))
        }
        val handler = object : GLRouteRequest.ResultsCallback {
            override fun onResult(route: GLRoute) { main.post {
                cancels.remove(requestId); request.close()
                if (!attached) { route.close(); return@post }
                callback(runCatching {
                    store(route)
                })
            } }
            override fun onError(error: GLMapError) { main.post {
                cancels.remove(requestId); request.close()
                if (attached) callback(Result.failure(featureError(error)))
            } }
        }
        val id = if (offline) request.startOffline(requireNotNull(offlineConfig) { "Offline routing requires a Valhalla configuration" }, handler) else request.startOnline(handler)
        cancels[requestId] = { GLRouteRequest.cancel(id) }
    }
    private fun store(route: GLRoute): RouteMessage {
        val id = resources.addTrackSource(object : NativeTrackSource {
            override fun trackData(color: Int) = route.getTrackData(color)
        })
        routes[id] = route
        val raw = route.trackCoordinates ?: throw FeatureError("empty_route", "Route has no geometry")
        val points = DoubleArray(raw.size)
        for (i in raw.indices step 2) {
            val point = MapGeoPoint(MapPoint(raw[i].toDouble(), raw[i + 1].toDouble()))
            points[i] = point.lon; points[i + 1] = point.lat
        }
        val bounds = route.getTrackData(0).use { it.bBox.message() }
        return RouteMessage(id, route.length, route.duration, bounds, points)
    }
    override fun buildRoute(steps: List<RouteStepMessage>): RouteMessage {
        require(steps.isNotEmpty())
        require(steps.all { it.lonLat.size >= 4 && it.lonLat.size % 2 == 0 && it.lonLat.all(Double::isFinite) && it.turn in 0L..2L && it.duration.isFinite() && it.duration >= 0 })
        return GLRouteBuilder().use { builder ->
            builder.setLanguage("en")
            val first = steps.first().lonLat; val last = steps.last().lonLat
            builder.addTargetPoint(GLRoutePoint(MapGeoPoint(first[1], first[0]), Double.NaN, GLRoutePoint.Type.BREAK))
            builder.addTargetPoint(GLRoutePoint(MapGeoPoint(last[last.size-1], last[last.size-2]), Double.NaN, GLRoutePoint.Type.BREAK))
            val turns = intArrayOf(GLRouteManeuver.Type.Continue, GLRouteManeuver.Type.Right, GLRouteManeuver.Type.Left)
            steps.forEach { step ->
                builder.addManeuver(turns[step.turn.toInt()], Array(step.lonLat.size/2) { i -> MapPoint.CreateFromGeoCoordinates(step.lonLat[2*i+1], step.lonLat[2*i]) }, null)
                builder.setManeuverShortInstruction(step.instruction); builder.setManeuverTime(step.duration)
            }
            builder.addManeuver(GLRouteManeuver.Type.Destination, arrayOf(MapPoint.CreateFromGeoCoordinates(last[last.size-1], last[last.size-2])), null)
            builder.setManeuverShortInstruction("Arrive at destination")
            store(builder.build() ?: throw FeatureError("invalid_route", "Cannot build route"))
        }
    }
    override fun updateNavigation(routeId: Long, point: GeoMessage, bearing: Double): NavigationMessage {
        val route = routes[routeId] ?: throw FeatureError("route_closed", "Route has been released")
        val tracker = trackers.getOrPut(routeId) { GLRouteTracker(route).apply { currentTargetPointIndex = 1 } }
        val maneuver = tracker.updateLocation(point.latitude, point.longitude, bearing.toFloat())
        return NavigationMessage(maneuver?.shortInstruction ?: "", tracker.distanceToNextManeuver, tracker.remainingDistance, tracker.remainingDuration, tracker.progressIndex, tracker.isOnRoute, MapGeoPoint(tracker.locationOnRoute).message())
    }
    override fun releaseRoute(routeId: Long) { resources.removeTrackSource(routeId); trackers.remove(routeId)?.close(); routes.remove(routeId)?.close() }
    override fun cancelRequest(requestId: Long) { cancels[requestId]?.invoke() }
    fun detach() {
        attached=false
        cancels.values.toList().forEach { it() }; cancels.clear()
        routes.keys.toList().forEach(::releaseRoute)
        RouteHostApi.setUp(messenger,null)
    }
}
