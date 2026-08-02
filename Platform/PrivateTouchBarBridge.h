#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PrivateTouchBarBridge : NSObject
+ (BOOL)isSupported;
+ (void)setSystemModalCloseBoxVisible:(BOOL)visible;
+ (void)setControlStripPresence:(BOOL)present identifier:(NSString *)identifier;
+ (void)addSystemTrayItem:(NSTouchBarItem *)item;
+ (void)removeSystemTrayItem:(NSTouchBarItem *)item;
+ (BOOL)presentSystemModalTouchBar:(NSTouchBar *)touchBar
                         placement:(NSInteger)placement;
+ (void)dismissSystemModalTouchBar:(NSTouchBar *)touchBar;
@end

NS_ASSUME_NONNULL_END
