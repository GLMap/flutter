package software.globus.flutter.core

import android.os.Handler
import android.os.Looper
import globus.glmap.GLMapTrackData
import globus.glmap.GLMapViewState
import io.flutter.plugin.common.BinaryMessenger
import java.util.WeakHashMap

/** Core-only protocol: a provider owns its source; callers own the returned track wrapper. */
interface NativeTrackSource { fun trackData(color: Int): GLMapTrackData }
data class MapCapture(val state: GLMapViewState, val density: Double)

/** Engine-scoped handoff of existing SDK resources, not a second camera/geometry model. Main thread only. */
class CoreResources private constructor() {
    companion object {
        private val engines = WeakHashMap<BinaryMessenger, CoreResources>()
        fun forMessenger(messenger: BinaryMessenger) = engines.getOrPut(messenger) { CoreResources() }
        fun release(messenger: BinaryMessenger) { engines.remove(messenger)?.clear() }
    }
    private val main = Handler(Looper.getMainLooper())
    private var nextId = 0L
    private val tracks = mutableMapOf<Long, NativeTrackSource>()
    private class MapEntry(val density:Double, val capture: ((Result<GLMapViewState>) -> Unit) -> Unit) {
        val pending = mutableSetOf<(Result<MapCapture>) -> Unit>()
    }
    private val maps = mutableMapOf<Int, MapEntry>()
    fun addTrackSource(source:NativeTrackSource):Long { val id=++nextId; tracks[id]=source; return id }
    fun containsTrack(id:Long) = tracks.containsKey(id)
    fun removeTrackSource(id:Long) { tracks.remove(id) }
    fun trackData(id:Long,color:Int):GLMapTrackData =
        (tracks[id] ?: throw IllegalStateException("route_closed")).trackData(color)
    fun registerMap(id:Int,density:Double,capture:((Result<GLMapViewState>)->Unit)->Unit) {
        unregisterMap(id); maps[id]=MapEntry(density,capture)
    }
    fun unregisterMap(id:Int) {
        val entry=maps.remove(id) ?: return
        val pending=entry.pending.toList(); entry.pending.clear()
        pending.forEach { it(Result.failure(IllegalStateException("map_disposed"))) }
    }
    fun capture(id:Int,reply:(Result<MapCapture>)->Unit) {
        val entry=maps[id] ?: run { reply(Result.failure(IllegalStateException("map_disposed"))); return }
        entry.pending.add(reply)
        try { entry.capture { result -> main.post {
            if (entry.pending.remove(reply)) reply(result.map { MapCapture(it,entry.density) })
            else result.getOrNull()?.close()
        } } } catch (error:Exception) { if (entry.pending.remove(reply)) reply(Result.failure(error)) }
    }
    private fun clear() { maps.keys.toList().forEach(::unregisterMap); tracks.clear() }
}
