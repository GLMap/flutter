#import <GLMapCore/GLMapCore.h>
NS_ASSUME_NONNULL_BEGIN
// Borrows doubles only for this call. GeometryBuilder creates SDK-owned geometry.
GLMapVectorObjectArray * _Nullable GLMapLabBuildPacked(const double *values, NSInteger count);
NS_ASSUME_NONNULL_END
