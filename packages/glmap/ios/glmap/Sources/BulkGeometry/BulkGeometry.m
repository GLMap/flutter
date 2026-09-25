#import "BulkGeometry.h"
#import <GLMapCore/GeometryBuilder.h>
#include <math.h>

GLMapVectorObjectArray *GLMapFlutterBuildPacked(const double *values, NSInteger count) {
    if (!values || count < 4 || count % 2 || count / 2 > INT32_MAX) return nil;
    for (NSInteger i = 0; i < count; i += 2) {
        double lon = values[i], lat = values[i + 1];
        if (!isfinite(lon) || !isfinite(lat) || lon < -180 || lon > 180 || lat < -90 || lat > 90) return nil;
    }
    GeometryBuilder *builder = [GeometryBuilder new];
    [builder addLine:count / 2 callback:^GLMapPoint(NSUInteger i) {
        return GLMapPointMakeFromGeoCoordinates(values[2 * i + 1], values[2 * i]);
    }];
    GLMapVectorObject *object = [builder build];
    if (!object) return nil;
    GLMapVectorObjectArray *objects = [GLMapVectorObjectArray new];
    [objects addObject:object];
    return objects;
}
