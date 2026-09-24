#import "GLSearchPlugin.h"
extern void GlobusFlutterSearchRegister(void *registrar);
@implementation GLSearchPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    GlobusFlutterSearchRegister((__bridge void *)registrar);
}
@end
