package software.globus.lab.glmap_lab

import globus.glmap.*

/** Retains accepted native geometry for restyle; the SDK owns update outcomes. */
internal class VectorLayerBridge(drawOrder: Int) {
    val layer = GLMapVectorLayer(drawOrder)
    private var objects: GLMapVectorObjectList? = null

    fun update(mutation: VectorMutationMessage, callback: (Result<VectorReply>) -> Unit) {
        val source = mutation.style ?: throw MapApiError("invalid_style", "MapCSS is required")
        val style = GLMapStyleParser().use { parser ->
            if (!parser.parseNextString(source)) throw MapApiError("invalid_style", parser.error?.toString())
            parser.finish() ?: throw MapApiError("invalid_style", parser.error?.toString())
        }
        style.use {
            val replacing = mutation.operation == VectorMutation.REPLACE
            val next = if (replacing) geometry(mutation) else
                objects ?: throw MapApiError("missing_geometry", "Call replace before setStyle")
            try {
                layer.setVectorObjectsWithResult(next, style) { result ->
                    callback(when (result) {
                        GLMapVectorLayer.UpdateResult.Ready -> Result.success(VectorReply.READY)
                        GLMapVectorLayer.UpdateResult.Superseded -> Result.success(VectorReply.SUPERSEDED)
                        GLMapVectorLayer.UpdateResult.Cancelled -> Result.success(VectorReply.CANCELLED)
                        GLMapVectorLayer.UpdateResult.Failed -> Result.success(VectorReply.FAILED)
                        else -> Result.failure(MapApiError("native_result", "Unknown vector update result"))
                    })
                }
            } catch (error: Exception) {
                if (replacing) next.close()
                throw error
            }
            if (replacing) {
                val previous = objects
                objects = next
                // The SDK retains native references before its setter returns.
                previous?.close()
            }
        }
    }

    private fun geometry(mutation: VectorMutationMessage): GLMapVectorObjectList {
        if ((mutation.lonLat == null) == (mutation.geoJson == null))
            throw MapApiError("invalid_geometry", "Specify packed coordinates or GeoJSON")
        mutation.geoJson?.let {
            try { return GLMapVectorObject.createFromGeoJSONOrThrow(it) }
            catch (error: Exception) { throw MapApiError("invalid_geometry", error.message) }
        }
        val values = checkNotNull(mutation.lonLat)
        if (values.size % 2 != 0 || values.size == 2)
            throw MapApiError("invalid_geometry", "A line needs zero or at least two points")
        val result = GLMapVectorObjectList()
        try {
            if (values.isNotEmpty()) GeometryBuilder().use { builder ->
                try { builder.addLineLonLat(values) }
                catch (error: IllegalArgumentException) { throw MapApiError("invalid_geometry", error.message) }
                val objectValue = builder.build() ?: throw MapApiError("invalid_geometry", "Could not build line")
                objectValue.use { result.insertObject(0, it) }
            }
            return result
        } catch (error: Exception) { result.close(); throw error }
    }

    fun pick(view: GLMapTextureView, x: Double, y: Double, tolerance: Double): String? {
        val density = view.resources.displayMetrics.density
                val values = objects ?: return null
        if (values.size() == 0L) return null
        // The JNI range is [start, end); passing size - 1 skips the last feature.
        return view.renderer.state?.use { state ->
            val point = state.convertDisplayToInternal(x * density, y * density, MapPoint())
            state.findNearPoint(values, 0, values.size(), point, tolerance)?.use { it.asGeoJSON() }
        }
    }

    fun diagnostics(id: Long): Map<String, Any> {
        val values = objects
        val result = mutableMapOf<String, Any>("id" to id, "objectCount" to (values?.size() ?: 0L))
        if (values != null && values.size() > 0) {
            val box = values.getBBox()
            result["bounds"] = listOf(box.origin_x, box.origin_y, box.size_x, box.size_y)
        }
        return result
    }

    fun close() { objects?.close(); objects = null; layer.dispose() }
}
