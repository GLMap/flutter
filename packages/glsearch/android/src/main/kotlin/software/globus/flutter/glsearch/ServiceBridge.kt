package software.globus.flutter.glsearch

import android.content.Context
import android.os.Handler
import android.os.Looper
import globus.glmap.*
import software.globus.flutter.core.CoreResources
import software.globus.flutter.core.NativeTrackSource
import kotlinx.coroutines.*
import globus.glsearch.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import java.io.File

internal fun GeoMessage.native() = MapGeoPoint(latitude, longitude)
internal fun MapGeoPoint.message() = GeoMessage(lat, lon)
internal fun featureError(error: Any) = FeatureError("sdk_error", error.toString())

internal class ServiceBridge(private val messenger: BinaryMessenger) : SearchHostApi {
    private val main = Handler(Looper.getMainLooper())
    private var attached = true
    private val cancels = mutableMapOf<Long, () -> Unit>()
    private val resources = CoreResources.forMessenger(messenger)
    private val locale by lazy { GLMapLocaleSettings(arrayOf("en", "native"), GLMapLocaleSettings.UnitSystem.International) }
    init { SearchHostApi.setUp(messenger,this) }
    fun place(obj: GLMapVectorObject): PlaceMessage {
        val name = obj.localizedName(locale)?.use { it.string } ?: "Unnamed place"
        val detail = obj.valueForKey("search:secondaryText")?.use { it.string } ?: ""
        return PlaceMessage(name, detail, MapGeoPoint(obj.point()).message())
    }
    override fun search(requestId: Long, text: String, offline: Boolean, autocomplete: Boolean, center: GeoMessage, categories: List<String>, callback: (Result<List<PlaceMessage>>) -> Unit) {
        val request = GLSearchRequest(if (autocomplete) GLSearchRequestType.Autocomplete else GLSearchRequestType.Search, text, center.native(), 30, arrayOf("en", "native"), categories.toTypedArray())
        val handler = object : GLSearchRequest.ResultsCallback {
            override fun onResult(objects: GLMapVectorObjectList) {
                val result = runCatching { objects.use { it.toArray().map { obj -> obj.use(::place) } } }
                main.post { cancels.remove(requestId); if (attached) callback(result) }
            }
            override fun onError(error: GLMapError) { main.post { cancels.remove(requestId); if (attached) callback(Result.failure(featureError(error))) } }
        }
        val id = if (offline) request.startOffline(handler) else request.startOnline(handler)
        cancels[requestId] = { GLSearchRequest.cancel(id) }
    }
    override fun pickObject(viewId: Long, x: Double, y: Double, callback: (Result<PlaceMessage?>) -> Unit) {
        resources.capture(viewId.toInt()) { result ->
            callback(result.fold(onSuccess = { capture -> runCatching {
                capture.state.use { GLSearch.MapObjectNearPoint(it,(x*capture.density).toFloat(),(y*capture.density).toFloat(),24.0)?.use(::place) }
            } }, onFailure = { Result.failure(FeatureError(it.message ?: "map_unavailable", it.message)) }))
        }
    }
    override fun cancelRequest(requestId: Long) { cancels[requestId]?.invoke() }
    fun detach() {
        attached=false
        cancels.values.toList().forEach { it() }; cancels.clear()
        SearchHostApi.setUp(messenger,null)
    }
}
