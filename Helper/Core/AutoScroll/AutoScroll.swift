//
// --------------------------------------------------------------------------
// AutoScroll.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Windows-style Auto Scroll (Smooze Pro's "Auto Scroll"), as a 'Click and Drag' action.
///
/// Flow:
///     - The user picks "Click and Drag -> Auto Scroll" on the Buttons tab (`kMFModifiedDragTypeAutoScroll`).
///     - MMF's normal button handling decides between click and drag, exactly like for the other drag actions. So a plain click only does something if the user also assigned a 'Click' action (e.g. "Middle Click").
///     - Once the drag starts, `ModifiedDragOutputAutoScroll` calls `begin(at:offset:)`, then `update(offset:)` for every mouse movement, then `end(cancel:)` when the button is released.
///     - While active, we post a continuous scroll event every frame. The speed depends on how far the mouse has moved from where the button was pressed.
///
/// The scroll curve and the anchor indicator are ported from LinearMouse (MIT, see `LICENSE-LinearMouse.txt`).
/// Scroll output is posted at the session level as pixel-based (continuous) events. `Scroll.m` lets continuous events pass through, so MMF's own scroll processing doesn't touch them.
/// All methods are main-thread-only.

import Cocoa

@objc class AutoScroll: NSObject {

    @objc static let shared = AutoScroll()

    // MARK: Constants

    private static let deadZone: Double = 10
    private static let maxScrollStep: Double = 160
    private static let tickInterval: TimeInterval = 1.0 / 60.0

    // MARK: Types

    private struct ReleaseAnimation {
        var velocity: CGVector
        var startTime: CFTimeInterval
        var duration: CFTimeInterval
    }

    // MARK: State

    private var config = AutoScrollConfig()
    private var anchor: CGPoint?        /// Non-nil while active
    private var offset = CGVector.zero  /// Mouse movement since the button was pressed. CG coordinates (y points down).

    private var timer: DispatchSourceTimer?
    private var lastVelocity = CGVector.zero
    private var subPixelRemainder = CGVector.zero
    private var releaseAnimation: ReleaseAnimation?

    private lazy var indicatorController = AutoScrollIndicatorWindowController()

    // MARK: Interface

    @objc func begin(at anchor: CGPoint, offset: CGVector) {

        assert(Thread.isMainThread)

        config = AutoScrollConfig.load()
        DDLogInfo("AutoScroll: Began - config: \(config)")

        stopReleaseAnimation()
        self.anchor = anchor
        self.offset = offset
        lastVelocity = .zero
        subPixelRemainder = .zero

        indicatorController.show(at: Self.cocoaPoint(anchor))
        indicatorController.update(delta: Self.indicatorDelta(offset))

        startTimerIfNeeded()
    }

    @objc func update(offset: CGVector) {

        assert(Thread.isMainThread)
        guard anchor != nil else { return }

        self.offset = offset
        indicatorController.update(delta: Self.indicatorDelta(offset))
    }

    @objc func end(cancel: Bool) {

        assert(Thread.isMainThread)
        guard anchor != nil else { return }

        DDLogInfo("AutoScroll: Ended (cancel: \(cancel))")

        anchor = nil
        indicatorController.hide()

        if !cancel {
            startReleaseAnimationIfNeeded()
        }
        if releaseAnimation == nil {
            stopTimer()
        }
    }

    // MARK: Scrolling

    private func startTimerIfNeeded() {

        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.tickInterval, repeating: Self.tickInterval, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
        self.timer = timer
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
        subPixelRemainder = .zero
    }

    private func tick() {

        if anchor != nil {

            /// Mouse above the anchor -> positive delta -> scroll up. Mouse left of it -> scroll left.
            var velocity = CGVector(dx: scrollAmount(for: -offset.dx),
                                    dy: scrollAmount(for: -offset.dy))
            if config.reverseHorizontal { velocity.dx = -velocity.dx }
            if config.reverseVertical { velocity.dy = -velocity.dy }

            lastVelocity = velocity
            postScroll(velocity)

        } else if let releaseAnimation {

            let progress = (CACurrentMediaTime() - releaseAnimation.startTime) / releaseAnimation.duration
            guard progress < 1 else {
                stopReleaseAnimation()
                return
            }

            let factor = CGFloat((1 - progress) * (1 - progress)) /// Ease out
            postScroll(CGVector(dx: releaseAnimation.velocity.dx * factor, dy: releaseAnimation.velocity.dy * factor))

        } else {
            stopTimer()
        }
    }

    private func scrollAmount(for delta: Double) -> Double {

        /// Pixels per tick for a mouse offset of `delta` from the anchor. Positive delta -> positive scroll.

        let adjusted = abs(delta) - Self.deadZone
        guard adjusted > 0 else { return 0 }

        let speed = config.acceleration / 10
        var value = adjusted * speed * 0.12 + sqrt(adjusted) * speed * 0.6

        /// Super Slowdown: Ramp up linearly inside an extra zone around the dead zone
        if config.superSlowdown > 0 {
            let slowZone = config.superSlowdown * 10
            if adjusted < slowZone {
                value *= adjusted / slowZone
            }
        }

        value = min(Self.maxScrollStep, value)
        return delta < 0 ? -value : value
    }

    private func postScroll(_ velocity: CGVector) {

        /// Carry sub-pixel amounts over to the next tick, so slow scrolling still moves
        subPixelRemainder.dx += velocity.dx
        subPixelRemainder.dy += velocity.dy
        let dx = subPixelRemainder.dx.rounded(.towardZero)
        let dy = subPixelRemainder.dy.rounded(.towardZero)
        subPixelRemainder.dx -= dx
        subPixelRemainder.dy -= dy

        guard dx != 0 || dy != 0 else { return }

        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0) else {
            return
        }
        event.flags = [] /// Held modifiers shouldn't turn this into zooming or horizontal scrolling
        event.post(tap: .cgSessionEventTap)
    }

    private func startReleaseAnimationIfNeeded() {

        guard config.animateRelease,
              config.releaseDuration > 0,
              lastVelocity.dx != 0 || lastVelocity.dy != 0 else {
            return
        }

        releaseAnimation = ReleaseAnimation(velocity: lastVelocity, startTime: CACurrentMediaTime(), duration: config.releaseDuration / 1000)
    }

    private func stopReleaseAnimation() {
        releaseAnimation = nil
        if anchor == nil {
            stopTimer()
        }
    }

    // MARK: Helpers

    private static func indicatorDelta(_ offset: CGVector) -> CGVector {
        /// The indicator uses Cocoa coordinates (y points up)
        return CGVector(dx: offset.dx, dy: -offset.dy)
    }

    private static func cocoaPoint(_ point: CGPoint) -> CGPoint {
        /// Convert from global CG coordinates (origin top-left of the primary screen) to Cocoa coordinates (origin bottom-left of the primary screen)
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }
}
