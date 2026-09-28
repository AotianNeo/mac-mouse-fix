//
// --------------------------------------------------------------------------
// AutoScrollConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Auto Scroll settings. Mirrors Smooze Pro's Auto Scroll options.
///
/// Turning Auto Scroll on and off:
///     Auto Scroll is a 'Click and Drag' action on the Buttons tab (`kMFModifiedDragTypeAutoScroll`). It's on for button N if the Remaps contain
///     "Button N, Click and Drag -> Auto Scroll" without keyboard modifiers. (The first such remap wins.)
///     `Remap.m` skips these remaps, so MMF's own drag handling (`ModifiedDrag`) never sees them.
///     If the same button has other actions (e.g. "Click -> Mission Control"), clicking doesn't toggle Auto Scroll, so those actions keep working.
///         Clicks are held back until the button is released and then replayed. So actions that need the button to be held (Hold, Click and Scroll) won't work on that button.
///
/// Everything else comes from the `AutoScroll` dict in config.plist.
///     Every key falls back to the value below if it's missing, because `Config.m` doesn't merge new keys from `default_config.plist` into an existing config.plist unless the `configVersion` changes.
///     Keep these fallbacks in sync with the `AutoScroll` dict in `default_config.plist`.
///
/// Keys:
/// - `actAsButtonOverLinks`  Clicking over a link / button / tab performs the normal click instead of starting Auto Scroll. (Dragging still starts Auto Scroll.)
/// - `holdToActivate`        Press, drag, and release to Auto Scroll. Releasing the button stops scrolling.
/// - `clickToToggle`         Click once to start Auto Scroll, click again (or click any button, or use the wheel) to stop. Combined with `holdToActivate`, this is the Windows behavior.
/// - `smartAutoScroll`       Clicking outside of a scrollable area performs the normal click instead of starting Auto Scroll. (Dragging still starts Auto Scroll.)
/// - `acceleration`          1...20. How quickly scrolling speeds up as you move away from the anchor point. 10 is LinearMouse's default speed.
/// - `superSlowdown`         0...20. Size of an extra slow zone around the dead zone for precise, slow scrolling (× 10 px). 0 turns it off.
/// - `animateRelease`        Keep gliding and slow down when Auto Scroll stops, instead of stopping instantly.
/// - `releaseDuration`       0...3000. Length of the release animation in milliseconds.
/// - `reverseVertical`       Flip the vertical scroll direction.
/// - `reverseHorizontal`     Flip the horizontal scroll direction.

import Cocoa

struct AutoScrollConfig: Equatable {

    var enabled = false     /// Derived from Remaps
    var button = 3          /// Derived from Remaps. MMF's 1-based numbering (3 = middle button)
    var actAsButtonOverLinks = true
    var holdToActivate = true
    var clickToToggle = true
    var smartAutoScroll = false
    var acceleration = 10.0
    var superSlowdown = 0.0
    var animateRelease = false
    var releaseDuration = 400.0
    var reverseVertical = false
    var reverseHorizontal = false

    /// Derived

    var isUsable: Bool {
        return enabled && (holdToActivate || clickToToggle)
    }
    var cgButtonNumber: Int64 {
        return Int64(button - 1) /// CGEvents use 0-based button numbers
    }

    /// Load

    static func load() -> AutoScrollConfig {

        var result = AutoScrollConfig()

        /// On/off and button from Remaps
        let remaps = config(kMFConfigKeyRemaps) as? [NSDictionary] ?? []
        guard let button = autoScrollButton(in: remaps) else {
            return result
        }
        result.enabled = true
        result.button = button
        let buttonHasOtherActions = remaps.contains { remapUsesButton($0, button) && !isAutoScrollRemap($0) }

        /// Other settings from the `AutoScroll` dict
        guard let dict = config("AutoScroll") as? NSDictionary else {
            if buttonHasOtherActions { result.clickToToggle = false }
            return result
        }

        func bool(_ key: String, _ fallback: Bool) -> Bool {
            return (dict[key] as? NSNumber)?.boolValue ?? fallback
        }
        func double(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
            let value = (dict[key] as? NSNumber)?.doubleValue ?? fallback
            return min(max(value, range.lowerBound), range.upperBound)
        }

        result.actAsButtonOverLinks = bool("actAsButtonOverLinks", result.actAsButtonOverLinks)
        result.holdToActivate       = bool("holdToActivate", result.holdToActivate)
        result.clickToToggle        = bool("clickToToggle", result.clickToToggle)
        result.smartAutoScroll      = bool("smartAutoScroll", result.smartAutoScroll)
        result.acceleration         = double("acceleration", result.acceleration, 1...20)
        result.superSlowdown        = double("superSlowdown", result.superSlowdown, 0...20)
        result.animateRelease       = bool("animateRelease", result.animateRelease)
        result.releaseDuration      = double("releaseDuration", result.releaseDuration, 0...3000)
        result.reverseVertical      = bool("reverseVertical", result.reverseVertical)
        result.reverseHorizontal    = bool("reverseHorizontal", result.reverseHorizontal)

        if buttonHasOtherActions { result.clickToToggle = false }

        return result
    }

    /// Remaps

    private static func isAutoScrollRemap(_ remap: NSDictionary) -> Bool {
        return ((remap[kMFRemapsKeyEffect] as? NSDictionary)?[kMFModifiedDragDictKeyType] as? String) == kMFModifiedDragTypeAutoScroll
    }

    private static func autoScrollButton(in remaps: [NSDictionary]) -> Int? {

        /// Find "Button N, Click and Drag -> Auto Scroll" without keyboard modifiers

        for remap in remaps where isAutoScrollRemap(remap) && (remap[kMFRemapsKeyTrigger] as? String) == kMFTriggerDrag {

            let modifiers = remap[kMFRemapsKeyModificationPrecondition] as? NSDictionary
            let keyboardModifiers = (modifiers?[kMFModificationPreconditionKeyKeyboard] as? NSNumber)?.uintValue ?? 0
            let buttonModifiers = modifiers?[kMFModificationPreconditionKeyButtons] as? [NSDictionary] ?? []

            guard keyboardModifiers == 0,
                  buttonModifiers.count == 1,
                  (buttonModifiers[0][kMFButtonModificationPreconditionKeyClickLevel] as? NSNumber)?.intValue == 1,
                  let button = (buttonModifiers[0][kMFButtonModificationPreconditionKeyButtonNumber] as? NSNumber)?.intValue,
                  button >= 3 else {
                continue
            }
            return button
        }
        return nil
    }

    private static func remapUsesButton(_ remap: NSDictionary, _ button: Int) -> Bool {

        /// Whether `button` triggers the remap or is one of its modifiers

        if let trigger = remap[kMFRemapsKeyTrigger] as? NSDictionary,
           (trigger[kMFButtonTriggerKeyButtonNumber] as? NSNumber)?.intValue == button {
            return true
        }
        let modifiers = remap[kMFRemapsKeyModificationPrecondition] as? NSDictionary
        let buttonModifiers = modifiers?[kMFModificationPreconditionKeyButtons] as? [NSDictionary] ?? []
        return buttonModifiers.contains { ($0[kMFButtonModificationPreconditionKeyButtonNumber] as? NSNumber)?.intValue == button }
    }
}
