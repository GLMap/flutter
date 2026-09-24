#import "GLMapPlugin.h"
extern void GlobusFlutterMapRegister(void *registrar);
@implementation GLMapPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    GlobusFlutterMapRegister((__bridge void *)registrar);
}
@end
