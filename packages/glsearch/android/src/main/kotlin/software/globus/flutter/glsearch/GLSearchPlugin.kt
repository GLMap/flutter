package software.globus.flutter.glsearch
import io.flutter.embedding.engine.plugins.FlutterPlugin
class GLSearchPlugin: FlutterPlugin {
    private var service:ServiceBridge?=null
    override fun onAttachedToEngine(binding:FlutterPlugin.FlutterPluginBinding) { service=ServiceBridge(binding.binaryMessenger) }
    override fun onDetachedFromEngine(binding:FlutterPlugin.FlutterPluginBinding) { service?.detach(); service=null; }
}
