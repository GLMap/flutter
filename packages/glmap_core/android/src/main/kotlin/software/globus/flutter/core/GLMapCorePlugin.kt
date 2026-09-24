package software.globus.flutter.core
import io.flutter.embedding.engine.plugins.FlutterPlugin
class GLMapCorePlugin: FlutterPlugin {
    private var service:SdkBridge?=null
    override fun onAttachedToEngine(binding:FlutterPlugin.FlutterPluginBinding) { service=SdkBridge(binding.applicationContext,binding.binaryMessenger,binding.flutterAssets) }
    override fun onDetachedFromEngine(binding:FlutterPlugin.FlutterPluginBinding) { service?.detach(); service=null; CoreResources.release(binding.binaryMessenger) }
}
