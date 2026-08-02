#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KeyboardBacklightBridge : NSObject
+ (float)brightness;
+ (BOOL)setBrightness:(float)brightness;
@end

NS_ASSUME_NONNULL_END
