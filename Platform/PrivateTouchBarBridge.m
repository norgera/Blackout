#import "PrivateTouchBarBridge.h"
#import <objc/message.h>
#import <dlfcn.h>

@implementation PrivateTouchBarBridge

typedef void (*DFRPresenceFn)(NSString *, BOOL);
typedef void (*DFRCloseBoxFn)(BOOL);

static void *DFRHandle(void) {
    static void *handle = NULL;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        const char *paths[] = {
            "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation",
            "/System/Library/PrivateFrameworks/DFRFoundation.framework/Versions/A/DFRFoundation"
        };

        for (int i = 0; i < 2 && handle == NULL; i++) {
            handle = dlopen(paths[i], RTLD_NOW | RTLD_LOCAL);
        }

    });

    return handle;
}

+ (BOOL)isSupported {
    return DFRHandle() != NULL &&
        [NSTouchBarItem respondsToSelector:NSSelectorFromString(@"addSystemTrayItem:")];
}

+ (void)setSystemModalCloseBoxVisible:(BOOL)visible {
    void *handle = DFRHandle();
    if (!handle) return;

    DFRCloseBoxFn fn =
        (DFRCloseBoxFn)dlsym(
            handle,
            "DFRSystemModalShowsCloseBoxWhenFrontMost"
        );

    if (fn) {
        fn(visible);
    }
}

+ (void)setControlStripPresence:(BOOL)present
                     identifier:(NSString *)identifier {
    void *handle = DFRHandle();
    if (!handle) return;

    DFRPresenceFn fn =
        (DFRPresenceFn)dlsym(
            handle,
            "DFRElementSetControlStripPresenceForIdentifier"
        );

    if (fn) {
        fn(identifier, present);
    }
}

+ (void)addSystemTrayItem:(NSTouchBarItem *)item {
    SEL selector = NSSelectorFromString(@"addSystemTrayItem:");

    if ([NSTouchBarItem respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(
            NSTouchBarItem.class,
            selector,
            item
        );
    }
}

+ (void)removeSystemTrayItem:(NSTouchBarItem *)item {
    SEL selector = NSSelectorFromString(@"removeSystemTrayItem:");

    if ([NSTouchBarItem respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(
            NSTouchBarItem.class,
            selector,
            item
        );
    }
}

+ (BOOL)presentSystemModalTouchBar:(NSTouchBar *)touchBar
                         placement:(NSInteger)placement {
    Class barClass = NSTouchBar.class;

    NSArray<NSString *> *selectorNames = @[
        @"presentSystemModalTouchBar:placement:systemTrayItemIdentifier:",
        @"presentSystemModalFunctionBar:placement:systemTrayItemIdentifier:",
        @"presentSystemModalFunctionBar:systemTrayItemIdentifier:"
    ];

    for (NSString *name in selectorNames) {
        SEL selector = NSSelectorFromString(name);

        if (![barClass respondsToSelector:selector]) {
            continue;
        }

        if ([name isEqualToString:
             @"presentSystemModalFunctionBar:systemTrayItemIdentifier:"]) {

            ((void (*)(id, SEL, id, id))objc_msgSend)(
                barClass,
                selector,
                touchBar,
                nil
            );
        } else {
            ((void (*)(id, SEL, id, NSInteger, id))objc_msgSend)(
                barClass,
                selector,
                touchBar,
                placement,
                nil
            );
        }

        return YES;
    }

    return NO;
}

+ (void)dismissSystemModalTouchBar:(NSTouchBar *)touchBar {
    Class barClass = NSTouchBar.class;

    NSArray<NSString *> *selectorNames = @[
        @"dismissSystemModalTouchBar:",
        @"dismissSystemModalFunctionBar:"
    ];

    for (NSString *name in selectorNames) {
        SEL selector = NSSelectorFromString(name);

        if ([barClass respondsToSelector:selector]) {
            ((void (*)(id, SEL, id))objc_msgSend)(
                barClass,
                selector,
                touchBar
            );

            return;
        }
    }
}

@end
