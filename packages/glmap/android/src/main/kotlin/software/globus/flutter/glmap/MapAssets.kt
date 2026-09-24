package software.globus.flutter.glmap
import android.content.Context
import globus.glmap.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
internal fun GeoMessage.native() = MapGeoPoint(latitude,longitude)
internal fun MapGeoPoint.message() = GeoMessage(lat,lon)
internal fun BoundsMessage.native() = GLMapBBox().apply {
    addPoint(MapPoint.CreateFromGeoCoordinates(south,west));addPoint(MapPoint.CreateFromGeoCoordinates(north,east))
}
internal class MapAssets(private val context:Context,private val assets:FlutterPlugin.FlutterAssets) {
    fun styleParser(directory:String?) = GLMapStyleParser { name ->
        try { context.assets.open("DefaultStyle.bundle/$name").use { it.readBytes() } }
        catch (_:java.io.IOException) {
            try { context.assets.open(assets.getAssetFilePathByName("${directory ?: return@GLMapStyleParser null}/$name")).use { it.readBytes() } }
            catch (_:java.io.IOException) { null }
        }
    }
}
