//
// --------------------------------------------------------------------------
// ModifiedDragOutputAutoScroll.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputAutoScroll.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "PointerFreeze.h"

@implementation ModifiedDragOutputAutoScroll

/// Notes:
/// - ModifiedDrag calls us on its own queue. `AutoScroll` is main-thread-only, so we dispatch to the main thread.
/// - The anchor is where the button was pressed (`origin`), not where the drag started (`usageOrigin`), like Auto Scroll on Windows.
/// - PointerFreeze keeps the real pointer at the anchor, so the scroll events go to the view under the anchor.
///     If the user turned off "lock pointer during drag", PointerFreeze draws a 'puppet' pointer that keeps moving.
/// - `originOffset` keeps accumulating mouse deltas while the pointer is frozen, so it's the distance the user has moved the mouse.

static ModifiedDragState *_drag;

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
}

+ (void)handleBecameInUse {
    
    CGPoint anchor = _drag->origin;
    CGVector offset = CGVectorMake(_drag->originOffset.x, _drag->originOffset.y);
    
    if (GeneralConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze freezePointerAtPosition:anchor];
    } else {
        [PointerFreeze freezeEventDispatchPointAtPosition:anchor];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [AutoScroll.shared beginAt:anchor offset:offset];
    });
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    CGVector offset = CGVectorMake(_drag->originOffset.x, _drag->originOffset.y);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [AutoScroll.shared updateWithOffset:offset];
    });
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [AutoScroll.shared endWithCancel:cancel];
    });
    
    [PointerFreeze unfreeze];
}

+ (void)suspend {}
+ (void)unsuspend {}

@end
