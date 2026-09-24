package software.globus.flutter.core

import android.content.Context
import android.os.Handler
import android.os.Looper
import globus.glmap.*
import kotlinx.coroutines.*
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

internal class SdkBridge(private val context: Context, private val messenger: BinaryMessenger, private val assets: FlutterPlugin.FlutterAssets) : CoreHostApi, GLMapManager.StateListener {
    private val main = Handler(Looper.getMainLooper())
    private val eventScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val events = SdkEventsApi(messenger)
    private var initialized = false
    private var attached = true
    private val cancels = mutableMapOf<Long, () -> Unit>()
    private val locale by lazy { GLMapLocaleSettings(arrayOf("en", "native"), GLMapLocaleSettings.UnitSystem.International) }

    init { CoreHostApi.setUp(messenger, this) }
    override fun initialize(apiKey: String) {
        if (!GLMapManager.Initialize(context, apiKey, null)) throw FeatureError("initialization", "GLMap initialization failed")
        if (!initialized) GLMapManager.addStateListener(this)
        initialized = true
        restoreAreas()
    }
    override fun addAssetDataSet(asset: String, dataSet: Long) {
        require(dataSet in 0L..2L)
        // Flutter asset names contain directories. The SDK's AssetManager cache
        // expects a flat filename, so materialize the asset through a regular file.
        val name = assets.getAssetFilePathByName(asset)
        val root = File(context.filesDir, "glmap-assets").canonicalFile
        val file = File(root, name).canonicalFile
        require(file.path.startsWith(root.path + File.separator))
        file.parentFile!!.mkdirs()
        val temporary = File.createTempFile("dataset-", ".tmp", file.parentFile)
        try {
            context.assets.open(name).use { input -> temporary.outputStream().use { input.copyTo(it) } }
            check(temporary.renameTo(file)) { "Cannot install bundled dataset" }
        } finally { temporary.delete() }
        if (!GLMapManager.AddDataSet(dataSet.toInt(), null, file.path, null, null)) {
            throw FeatureError("dataset_error", "Cannot open dataset $asset")
        }
    }
    fun styleParser(assetDirectory: String?) = GLMapStyleParser { name ->
        try { context.assets.open("DefaultStyle.bundle/$name").use { it.readBytes() } }
        catch (_: java.io.IOException) {
            try { context.assets.open(assets.getAssetFilePathByName("${assetDirectory ?: return@GLMapStyleParser null}/$name")).use { it.readBytes() } }
            catch (_: java.io.IOException) { null }
        }
    }

    private fun region(id: Long) = GLMapManager.GetMapWithID(id) ?: throw FeatureError("unknown_region", "Region $id is unavailable")
    override fun regions(parent: Long?, refresh: Boolean, callback: (Result<List<RegionMessage>>) -> Unit) {
        fun read() = (if (parent == null) GLMapManager.GetMaps() else region(parent).maps).orEmpty().map {
            RegionMessage(it.mapID, it.getLocalizedName(locale) ?: "Region ${it.mapID}", it.isCollection,
                it.dataSetsWithState(GLMapInfo.State.DOWNLOADED).toLong(), it.dataSetsWithState(GLMapInfo.State.IN_PROGRESS).toLong(), it.getSizeOnServer(7), it.getSizeOnDisk(7))
        }
        if (refresh) GLMapManager.UpdateMapList { _, error -> main.post { callback(if (error == null) runCatching(::read) else Result.failure(featureError(error))) } }
        else callback(runCatching(::read))
    }
    override fun downloadRegion(id: Long, mask: Long) { GLMapManager.DownloadDataSets(region(id), mask.toInt()) }
    override fun cancelRegionDownload(id: Long) { GLMapManager.getDownloadTasks(id, 7)?.forEach { it.cancel() } }
    override fun deleteRegion(id: Long, mask: Long) { GLMapManager.DeleteDataSets(region(id), mask.toInt()) }
    override fun cancelRequest(requestId: Long) { cancels[requestId]?.invoke() }
    private val areaDirectory get() = File(context.filesDir, "glmap-areas").apply { mkdirs() }
    private val areaExtensions = listOf("vmtar", "navtar", "eletar")
    private fun registerArea(kind: Int, bounds: BoundsMessage, file: File) {
        // Re-registering a custom file is not idempotent in the SDK. Replace our
        // own registration so repeated calls and initialization are equivalent.
        GLMapManager.RemoveDataSet(kind, file.path)
        check(GLMapManager.AddDataSet(kind, bounds.native(), file.path, null, null)) { "Cannot register downloaded dataset" }
    }
    private fun restoreAreas() {
        // Only completed downloads have these extensions. Names retain the
        // bounds needed by the SDK; interrupted .part files are never registered.
        areaDirectory.listFiles().orEmpty().forEach { file ->
            val kind = areaExtensions.indexOf(file.extension)
            val parts = file.nameWithoutExtension.split('_')
            val coordinates = parts.mapNotNull(String::toDoubleOrNull)
            if (kind >= 0 && parts.size == 4 && coordinates.size == 4 && coordinates.all(Double::isFinite)) {
                registerArea(kind, BoundsMessage(coordinates[0], coordinates[1], coordinates[2], coordinates[3]), file)
            }
        }
    }
    override fun downloadArea(requestId: Long, bounds: BoundsMessage, mask: Long, callback: (Result<Unit>) -> Unit) {
        val kinds = (0..2).filter { mask.toInt() and (1 shl it) != 0 }
        if (kinds.isEmpty()) { callback(Result.failure(FeatureError("invalid_argument", "Choose a dataset"))); return }
        val box = bounds.native()
        val ids = mutableListOf<Long>()
        var remaining = kinds.size
        var failure: Throwable? = null
        cancels[requestId] = { ids.forEach(GLMapManager::CancelDownloadTask) }
        fun finished(kind: Int, file: File, error: Throwable?) {
            if (error != null && failure == null) failure = error
            if (attached) eventScope.launch { runCatching { events.downloadProgress(requestId, kind.toLong(), file.length(), file.length(), error?.message, true, true) } }
            remaining--
            if (remaining == 0) { cancels.remove(requestId); if (attached) callback(failure?.let { Result.failure(it) } ?: Result.success(Unit)) }
        }
        kinds.forEach { kind ->
            val file = File(areaDirectory, "${bounds.south}_${bounds.west}_${bounds.north}_${bounds.east}.${areaExtensions[kind]}")
            if (file.exists()) {
                finished(kind, file, runCatching { registerArea(kind, bounds, file) }.exceptionOrNull())
                return@forEach
            }
            val partial = File.createTempFile("area-", ".part", areaDirectory)
            ids += GLMapManager.DownloadDataSet(kind, partial.path, box, object : GLMapManager.DownloadCallback {
                override fun onProgress(total: Long, downloaded: Long, speed: Double) { main.post { if (attached) eventScope.launch { runCatching { events.downloadProgress(requestId, kind.toLong(), downloaded, total, null, false, true) } } } }
                override fun onFinished(error: GLMapError?) { main.post {
                    val failure = runCatching {
                        if (error != null) throw featureError(error)
                        // Another request for the same bounds may have completed.
                        if (!file.exists()) check(partial.renameTo(file)) { "Cannot install downloaded dataset" }
                        registerArea(kind, bounds, file)
                    }.exceptionOrNull()
                    partial.delete()
                    finished(kind, file, failure)
                } }
            })
        }
    }
    private fun progress(task: GLMapDownloadTask, finished: Boolean) {
        if (attached) eventScope.launch { runCatching { events.downloadProgress(task.map.mapID, task.dataSet.toLong(), task.downloaded.toLong(), task.total.toLong(), task.error?.toString(), finished, false) } }
    }
    override fun onStartDownloading(task: GLMapDownloadTask) = progress(task, false)
    override fun onDownloadProgress(task: GLMapDownloadTask) = progress(task, false)
    override fun onFinishDownloading(task: GLMapDownloadTask) = progress(task, true)
    override fun onStateChanged(map: GLMapInfo?, dataSet: Int) {}
    fun detach() {
        attached = false
        eventScope.cancel()
        cancels.values.toList().forEach { it() }; cancels.clear()
        if (initialized) GLMapManager.removeStateListener(this)
        CoreHostApi.setUp(messenger, null)
    }
}
