//
// WindowsScrollHook.m
// Mac Mouse Fix - Windows-style Linear Scroll (No Acceleration)
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface WindowsConstantCurve : NSObject
@property (nonatomic, assign) double stepSize;
- (instancetype)initWithStepSize:(double)stepSize;
- (double)evaluateAt:(double)x;
- (double)evaluate:(double)x;
@end

@implementation WindowsConstantCurve

- (instancetype)initWithStepSize:(double)stepSize {
    self = [super init];
    if (self) {
        _stepSize = stepSize;
    }
    return self;
}

- (double)evaluateAt:(double)x {
    return _stepSize;
}

- (double)evaluate:(double)x {
    return _stepSize;
}

@end

static double getStepSizeFromConfig(void) {
    NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    NSString *configPath = [appSupport stringByAppendingPathComponent:@"com.nuebling.mac-mouse-fix/config.plist"];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:configPath];
    
    if (dict && [dict objectForKey:@"Scroll"]) {
        NSDictionary *scrollDict = [dict objectForKey:@"Scroll"];
        NSNumber *customStep = [scrollDict objectForKey:@"linearStepSize"];
        if (customStep && [customStep doubleValue] > 0) {
            return [customStep doubleValue];
        }
        NSString *speed = [scrollDict objectForKey:@"speed"];
        if ([speed isEqualToString:@"low"]) {
            return 20.0; // 2 lines
        } else if ([speed isEqualToString:@"high"]) {
            return 50.0; // 5 lines
        }
    }
    return 30.0; // Standard Windows default: 3 lines per notch (3 * 10px = 30px)
}

static BOOL getSmoothEnabledFromConfig(void) {
    NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    NSString *configPath = [appSupport stringByAppendingPathComponent:@"com.nuebling.mac-mouse-fix/config.plist"];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:configPath];
    
    if (dict && [dict objectForKey:@"Scroll"]) {
        NSDictionary *scrollDict = [dict objectForKey:@"Scroll"];
        NSString *smooth = [scrollDict objectForKey:@"smooth"];
        if ([smooth isEqualToString:@"off"]) {
            return NO;
        } else if ([smooth isEqualToString:@"regular"] || [smooth isEqualToString:@"high"] || [smooth isEqualToString:@"low"]) {
            return YES;
        }
    }
    return NO; // Windows default: discrete line scroll
}

// Swizzled methods
static id Hook_accelerationCurve(id self, SEL _cmd) {
    double step = getStepSizeFromConfig();
    return [[WindowsConstantCurve alloc] initWithStepSize:step];
}

static id Hook_fastScrollCurve(id self, SEL _cmd) {
    return nil; // Strictly disable consecutive fast scroll amplification
}

static BOOL Hook_useAppleAcceleration(id self, SEL _cmd) {
    return NO; // Never fall back to macOS kernel acceleration
}

static BOOL Hook_smoothEnabled(id self, SEL _cmd) {
    return getSmoothEnabledFromConfig();
}

__attribute__((constructor))
static void InitWindowsScrollHook(void) {
    NSLog(@"[WindowsScroll] Initializing Windows Linear Scroll Hook for Mac Mouse Fix...");
    
    Class scrollConfigClass = objc_getClass("_TtC20Mac_Mouse_Fix_Helper12ScrollConfig");
    if (!scrollConfigClass) {
        NSLog(@"[WindowsScroll] Warning: ScrollConfig class not found immediately, deferring to runloop");
        dispatch_async(dispatch_get_main_queue(), ^{
            Class cls = objc_getClass("_TtC20Mac_Mouse_Fix_Helper12ScrollConfig");
            if (cls) {
                InitWindowsScrollHook();
            }
        });
        return;
    }
    
    SEL accelSel = sel_registerName("accelerationCurve");
    SEL fastSel = sel_registerName("fastScrollCurve");
    SEL appleAccelSel = sel_registerName("useAppleAcceleration");
    SEL smoothSel = sel_registerName("smoothEnabled");
    
    class_replaceMethod(scrollConfigClass, accelSel, (IMP)Hook_accelerationCurve, "@@:");
    class_replaceMethod(scrollConfigClass, fastSel, (IMP)Hook_fastScrollCurve, "@@:");
    class_replaceMethod(scrollConfigClass, appleAccelSel, (IMP)Hook_useAppleAcceleration, "B@:");
    class_replaceMethod(scrollConfigClass, smoothSel, (IMP)Hook_smoothEnabled, "B@:");
    
    NSLog(@"[WindowsScroll] Successfully activated! Windows 1:1 mouse wheel active (3 lines/tick, zero acceleration, zero fast-scroll multiplier).");
}
