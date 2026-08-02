#import "KeyboardBacklightBridge.h"
#import <objc/message.h>

@implementation KeyboardBacklightBridge

static id KeyboardBrightnessClient(void) {
    static id client = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *framework = [NSBundle bundleWithPath:
            @"/System/Library/PrivateFrameworks/CoreBrightness.framework"];
        [framework load];
        Class clientClass = NSClassFromString(@"KeyboardBrightnessClient");
        if (clientClass) {
            client = [[clientClass alloc] init];
        }
    });
    return client;
}

static NSArray<NSNumber *> *KeyboardBacklightIDs(void) {
    id client = KeyboardBrightnessClient();
    SEL selector = NSSelectorFromString(@"copyKeyboardBacklightIDs");
    if (!client || ![client respondsToSelector:selector]) {
        return nil;
    }
    return ((id (*)(id, SEL))objc_msgSend)(client, selector);
}

+ (float)brightness {
    id client = KeyboardBrightnessClient();
    NSNumber *keyboardID = KeyboardBacklightIDs().firstObject;
    SEL selector = NSSelectorFromString(@"brightnessForKeyboard:");
    if (!client || !keyboardID || ![client respondsToSelector:selector]) {
        return -1;
    }
    return ((float (*)(id, SEL, unsigned long long))objc_msgSend)(
        client,
        selector,
        keyboardID.unsignedLongLongValue
    );
}

+ (BOOL)setBrightness:(float)brightness {
    id client = KeyboardBrightnessClient();
    NSArray<NSNumber *> *keyboardIDs = KeyboardBacklightIDs();
    SEL selector = NSSelectorFromString(
        @"setBrightness:fadeSpeed:commit:forKeyboard:"
    );
    if (!client || keyboardIDs.count == 0 ||
        ![client respondsToSelector:selector]) {
        return NO;
    }
    BOOL succeeded = YES;
    for (NSNumber *keyboardID in keyboardIDs) {
        BOOL didSet = ((BOOL (*)(id, SEL, float, int, BOOL, unsigned long long))
            objc_msgSend)(
                client,
                selector,
                brightness,
                350,
                YES,
                keyboardID.unsignedLongLongValue
            );
        succeeded = succeeded && didSet;
    }
    return succeeded;
}
@end
