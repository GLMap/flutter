#import "GLRoutePlugin.h"
extern void GlobusFlutterRouteRegister(void *registrar);
@implementation GLRoutePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    GlobusFlutterRouteRegister((__bridge void *)registrar);
}
@end
