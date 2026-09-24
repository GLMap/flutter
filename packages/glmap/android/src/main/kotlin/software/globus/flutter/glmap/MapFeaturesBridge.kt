package software.globus.flutter.glmap

import android.graphics.*
import globus.glmap.*
import kotlinx.coroutines.*
import software.globus.flutter.core.CoreResources
import io.flutter.plugin.common.BinaryMessenger

internal class MapFeaturesBridge(private val view: GLMapTextureView, private val sdk: MapAssets, private val resources: CoreResources, private val messenger: BinaryMessenger, id: Int) : MapFeaturesHostApi {
    private val suffix = id.toString()
    private val renderer get() = view.renderer
    private var disposed = false
    private val objects = mutableMapOf<Long, List<GLMapDrawObject>>()
    private val retained = mutableMapOf<Long, List<GLNativeObject>>()
    private var raster: GLMapRasterTileSource? = null
    private val routeIds = mutableMapOf<Long, Long>()
    private val eventScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val events = MapEventsApi(messenger, suffix)
    private val density = view.resources.displayMetrics.density.toDouble()
    init { MapFeaturesHostApi.setUp(messenger, this, suffix) }
    fun tap(x: Float, y: Float, longPress: Boolean) {
        if (disposed) return
        val p = MapGeoPoint(renderer.convertDisplayToInternal(x.toDouble(), y.toDouble()))
        eventScope.launch { runCatching { events.tap(p.message(), x / density, y / density, longPress) } }
    }
    private fun checkOpen() { check(!disposed) { "Map has been removed" } }
    private fun replace(id: Long, values: List<GLMapDrawObject>, keep: List<GLNativeObject> = emptyList()) {
        checkOpen(); removeObject(id); objects[id] = values; retained[id] = keep
        values.forEach { renderer.add(it) }
    }
    override fun removeObject(id: Long) {
        routeIds.remove(id)
        objects.remove(id)?.forEach { renderer.remove(it); it.close() }
        retained.remove(id)?.forEach { it.close() }
    }
    override fun setStyleOptions(options: Map<String, String>, assetDirectory: String?) {
        checkOpen()
        sdk.styleParser(assetDirectory).use { parser ->
            parser.setOptions(options, true)
            val style = parser.parseFromResources() ?: throw FeatureError("invalid_style", "Cannot parse map style")
            style.use { renderer.setStyle(it) }
        }
        renderer.reloadTiles()
    }
    override fun setTerrain(altitudeScale: Double, hillshades: Boolean, contours: Boolean, slopes: Boolean) {
        checkOpen(); require(altitudeScale.isFinite() && altitudeScale in 0.0..10.0)
        renderer.altitudeScale = altitudeScale.toFloat(); renderer.drawHillshades = hillshades
        renderer.drawElevationLines = contours; renderer.drawSlopes = slopes
    }
    override fun setOnlineTiles(enabled: Boolean) { checkOpen(); GLMapManager.SetTileDownloadingAllowed(enabled); renderer.reloadTiles() }
    override fun setRasterSource(urlTemplate: String?, attribution: String) {
        checkOpen()
        if (urlTemplate == null) {
            renderer.setBase(GLMapVectorTileSource())
        } else {
            require(urlTemplate.startsWith("https://") && listOf("{z}", "{x}", "{y}").all(urlTemplate::contains))
            val storage = GLMapFileStorage(view.context.cacheDir).findStorage("raster", true)?.findFile("tiles-${urlTemplate.hashCode()}.db", true)
            val source = object : GLMapRasterTileSource(storage) {
                override fun urlForTilePos(x: Int, y: Int, z: Int) = urlTemplate.replace("{z}", "$z").replace("{x}", "$x").replace("{y}", "$y")
            }
            source.setValidZoomMask((1 shl 20) - 1)
            source.setAttributionText(attribution)
            renderer.setBase(source)
            raster?.close(); raster = source
        }
        if (urlTemplate == null) { raster?.close(); raster = null }
        renderer.reloadTiles()
    }
    override fun animateCamera(center: GeoMessage, zoom: Double, duration: Double, fly: Boolean) {
        checkOpen(); require(duration.isFinite() && duration >= 0 && zoom.isFinite())
        renderer.animate {
            it.setDuration(duration)
            it.flyToMode = if (fly) GLMapAnimation.FlyToMode.Enabled else GLMapAnimation.FlyToMode.Disabled
            renderer.mapGeoCenter = center.native(); renderer.mapZoom = zoom
        }
    }
    override fun fitBounds(bounds: BoundsMessage) {
        checkOpen(); val box = bounds.native()
        renderer.doWhenSurfaceCreated { renderer.mapZoom = renderer.mapZoomForBBox(box); renderer.mapCenter = box.center() }
    }
    private fun image(png: ByteArray): Bitmap = BitmapFactory.decodeByteArray(png, 0, png.size) ?: throw FeatureError("invalid_image", "Expected PNG image")
    override fun setImage(id: Long, point: GeoMessage, png: ByteArray) {
        val bitmap = image(png)
        val marker = GLMapImage(3).apply { setBitmap(bitmap); setOffset(bitmap.width / 2, bitmap.height / 2); position = MapPoint(point.native()) }
        replace(id, listOf(marker))
    }
    override fun setImageGroup(id: Long, points: List<GeoMessage>, png: ByteArray) {
        val bitmap = image(png)
        val positions = points.map { MapPoint(it.native()) }
        val source = object : GLMapImageGroupCallback {
            override fun getImageVariantsCount() = 1
            override fun getImageVariantBitmap(i: Int) = bitmap
            override fun getImageVariantOffset(i: Int) = MapPoint(bitmap.width / 2.0, bitmap.height / 2.0)
            override fun getImagesCount() = positions.size
            override fun getImageIndex(i: Int) = 0
            override fun getImagePos(i: Int) = positions[i]
            override fun updateStarted() {}
            override fun updateFinished() {}
        }
        replace(id, listOf(GLMapImageGroup(source, 3)))
    }
    override fun setMarkers(id: Long, geoJson: String, png: ByteArray, clusteringRadius: Double) {
        require(clusteringRadius.isFinite() && clusteringRadius >= 0)
        val source = GLMapVectorObject.createFromGeoJSONOrThrow(geoJson)
        val items = source.toArray()
        val styles = GLMapMarkerStyleCollection()
        styles.addStyle(GLMapMarkerImage("marker", image(png)))
        val textStyle = GLMapVectorStyle.createStyle("{text-color:black;font-size:13;font-stroke-width:1pt;font-stroke-color:white;}")!!
        styles.setDataCallback(object : GLMapMarkerStyleCollectionDataCallback() {
            override fun getLocation(marker: Any) = (marker as GLMapVectorObject).point()
            override fun fillData(marker: Any, data: Long) { GLMapMarkerStyleCollection.setMarkerStyle(data, 0) }
            override fun fillUnionData(count: Int, data: Long) {
                GLMapMarkerStyleCollection.setMarkerStyle(data, 0)
                GLMapMarkerStyleCollection.setMarkerText(data, count.toString(), GLMapTextAlignment.Undefined, Point(0, 0), textStyle)
            }
        })
        val layer = GLMapMarkerLayer(items, styles, clusteringRadius, 3)
        replace(id, listOf(layer), listOf(source, styles, textStyle) + items)
    }
    override fun setBalloon(id: Long, point: GeoMessage, text: String) {
        val bitmap = Bitmap.createBitmap(80, 60, Bitmap.Config.ARGB_8888)
        Canvas(bitmap).drawRoundRect(0f, 0f, 80f, 60f, 12f, 12f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE })
        val style = GLMapVectorStyle.createStyle("{text-color:#172B4D;font-size:15;}")!!
        val balloon = GLMapBalloon(8).apply {
            setBackgroundBitmap(bitmap, Rect(20, 20, 20, 20))
            setText(text, style, Rect(12, 8, 12, 8), null)
            position = MapPoint(point.native())
        }
        replace(id, listOf(balloon), listOf(style))
    }
    override fun setTrack(id: Long, lonLat: DoubleArray, progress: Double, arrows: Boolean) {
        require(lonLat.size >= 4 && lonLat.size % 2 == 0)
        val data = GLMapTrackData({ index, native -> GLMapTrackData.setPointDataGeo(native, lonLat[index*2+1], lonLat[index*2], Color.rgb(39, 100, 225)) }, lonLat.size / 2)
        val style = GLMapVectorStyle.createStyle(if (arrows) "{width:14pt;fill-image:\"track-arrow.svg\";}" else "{width:7pt;}")!!
        val track = GLMapTrack(4).apply { setData(data, style, null); setProgressColor(Color.GRAY); setProgressIndex(progress) }
        val values = mutableListOf<GLMapDrawObject>(track)
        val keep = mutableListOf<GLNativeObject>(data, style)
        if (arrows) {
            val builder = GeometryBuilder(); builder.addLineLonLat(lonLat)
            val line = builder.build()!!; builder.close()
            val head = Bitmap.createBitmap(40, 40, Bitmap.Config.ARGB_8888)
            val path = Path().apply { moveTo(20f,0f); lineTo(40f,40f); lineTo(20f,30f); lineTo(0f,40f); close() }
            Canvas(head).drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(30, 180, 100) })
            val arrow = GLMapLineArrow(5).apply { setLineStyle(style, head); setLine(line, (lonLat.size/4).coerceAtMost(lonLat.size/2-1)) }
            values += arrow; keep += line
        }
        replace(id, values, keep)
    }
    override fun setRouteTrack(id: Long, routeId: Long, progress: Double) {
        val existing = objects[id]?.singleOrNull() as? GLMapTrack
        if (existing != null && routeIds[id] == routeId && resources.containsTrack(routeId)) {
            existing.setProgressIndex(progress)
            return
        }
        val data = resources.trackData(routeId,Color.rgb(20, 180, 100))
        val style = GLMapVectorStyle.createStyle("{width:8pt;}")!!
        val track = existing ?: GLMapTrack(4)
        track.setData(data, style, null); track.setProgressColor(Color.GRAY); track.setProgressIndex(progress)
        if (existing == null) replace(id, listOf(track), listOf(data, style))
        else { retained.remove(id)?.forEach { it.close() }; retained[id] = listOf(data, style) }
        routeIds[id] = routeId
    }
    override fun project(points: List<GeoMessage>, callback: (Result<DoubleArray>) -> Unit) {
        callback(runCatching { DoubleArray(points.size * 2).also { out -> points.forEachIndexed { i, p ->
            val value = renderer.convertInternalToDisplay(MapPoint(p.native()))
            out[i*2] = value.x / density; out[i*2+1] = value.y / density
        } } })
    }
    fun dispose() {
        if (disposed) return
        raster?.close(); raster = null
        objects.keys.toList().forEach(::removeObject); disposed = true; eventScope.cancel()
        MapFeaturesHostApi.setUp(messenger, null, suffix)
    }
}
