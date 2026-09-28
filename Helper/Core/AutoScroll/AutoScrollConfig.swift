//
// --------------------------------------------------------------------------
// AutoScrollConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Auto Scroll tuning. Mirrors Smooze Pro's Auto Scroll options.
///
/// Auto Scroll itself is turned on and off on the Buttons tab ("Click and Drag -> Auto Scroll"). These settings come from the `AutoScroll` dict in config.plist.
///     Every key falls back to the value below if it's missing, because `Config.m` doesn't merge new keys from `default_config.plist` into an existing config.plist unless the `configVersion` changes.
///     Keep these fallbacks in sync with the `AutoScroll` dict in `default_config.plist`.
///
/// Keys:
/// - `acceleration`          1...20. How quickly scrolling speeds up as you move away from the anchor point. 10 is LinearMouse's default speed.
/// - `superSlowdown`         0...20. Size of an extra slow zone around the dead zone for precise, slow scrolling (× 10 px). 0 turns it off.
/// - `animateRelease`        Keep gliding and slow down when Auto Scroll stops, instead of stopping instantly.
/// - `releaseDuration`       0...3000. Length of the release animation in milliseconds.
/// - `reverseVertical`       Flip the vertical scroll direction.
/// - `reverseHorizontal`     Flip the horizontal scroll direction.

import Cocoa

struct AutoScrollConfig: Equatable {

    var acceleration = 10.0
    var superSlowdown = 0.0
    var animateRelease = false
    var releaseDuration = 400.0
    var reverseVertical = false
    var reverseHorizontal = false

    static func load() -> AutoScrollConfig {

        var result = AutoScrollConfig()
        guard let dict = config("AutoScroll") as? NSDictionary else {
            return result
        }

        func bool(_ key: String, _ fallback: Bool) -> Bool {
            return (dict[key] as? NSNumber)?.boolValue ?? fallback
        }
        func double(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
            let value = (dict[key] as? NSNumber)?.doubleValue ?? fallback
            return min(max(value, range.lowerBound), range.upperBound)
        }

        result.acceleration         = double("acceleration", result.acceleration, 1...20)
        result.superSlowdown        = double("superSlowdown", result.superSlowdown, 0...20)
        result.animateRelease       = bool("animateRelease", result.animateRelease)
        result.releaseDuration      = double("releaseDuration", result.releaseDuration, 0...3000)
        result.reverseVertical      = bool("reverseVertical", result.reverseVertical)
        result.reverseHorizontal    = bool("reverseHorizontal", result.reverseHorizontal)

        return result
    }
}
