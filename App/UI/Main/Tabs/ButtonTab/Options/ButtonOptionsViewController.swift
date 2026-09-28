//
// --------------------------------------------------------------------------
// ButtonOptionsViewController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa
import ReactiveCocoa
import ReactiveSwift

class ButtonOptionsViewController: NSViewController {

    /// Vars
    
    static var instance: ButtonOptionsViewController? = nil
    
    var lockPointer = ConfigValue<Bool>(configPath: "General.lockPointerDuringDrag")
    
    /// [Fork] Auto Scroll. Defaults and ranges must match `AutoScrollConfig.swift` in the Helper.
    var autoScrollAcceleration = ConfigValue<Double>(configPath: "AutoScroll.acceleration")
    var autoScrollSuperSlowdown = ConfigValue<Double>(configPath: "AutoScroll.superSlowdown")
    var autoScrollAnimateRelease = ConfigValue<Bool>(configPath: "AutoScroll.animateRelease")
    var autoScrollReleaseDuration = ConfigValue<Double>(configPath: "AutoScroll.releaseDuration")
    var autoScrollReverseVertical = ConfigValue<Bool>(configPath: "AutoScroll.reverseVertical")
    var autoScrollReverseHorizontal = ConfigValue<Bool>(configPath: "AutoScroll.reverseHorizontal")
    
    /// IB outlets & actions
    
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var lockPointerButton: NSButton!
        
    @IBAction func done(_ sender: Any) {
        ButtonOptionsViewController.remove()
    }
    
    /// Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        lockPointerButton.reactive.boolValue <~ lockPointer
        lockPointer <~ lockPointerButton.reactive.boolValues
        
        /// [Fork] Auto Scroll
        addAutoScrollSection()
        
        /// Adjust views for Tahoe
        if #available(macOS 26.0, *) {
            self.view.setValue(true, forKey: "prefersCompactControlSizeMetrics")
        }
    }
    
    /// [Fork] Auto Scroll section
    ///     Built in code instead of in the xib. Goes between the 'lock pointer' hint and the Done button.
    
    private func addAutoScrollSection() {
        
        /// Title
        let title = NSTextField(labelWithString: MFLocalizedString("drag-effect.auto-scroll", comment: ""))
        title.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        
        /// Sliders
        let acceleration = makeSlider(autoScrollAcceleration, range: 1...20, step: 1, defaultValue: 10, format: { "\(Int($0))" })
        acceleration.slider.toolTip = MFLocalizedString("button-options.auto-scroll.acceleration.hint", comment: "")
        let superSlowdown = makeSlider(autoScrollSuperSlowdown, range: 0...20, step: 1, defaultValue: 0, format: { "\(Int($0))" })
        superSlowdown.slider.toolTip = MFLocalizedString("button-options.auto-scroll.super-slowdown.hint", comment: "")
        let releaseDuration = makeSlider(autoScrollReleaseDuration, range: 50...2000, step: 50, defaultValue: 400, format: { "\(Int($0)) ms" })
        
        /// Checkboxes
        let animateRelease = makeCheckbox(autoScrollAnimateRelease, title: MFLocalizedString("button-options.auto-scroll.animate-release", comment: ""))
        animateRelease.toolTip = MFLocalizedString("button-options.auto-scroll.animate-release.hint", comment: "")
        releaseDuration.slider.reactive.isEnabled <~ autoScrollAnimateRelease.producer
        let reverseVertical = makeCheckbox(autoScrollReverseVertical, title: MFLocalizedString("button-options.auto-scroll.reverse-vertical", comment: ""))
        let reverseHorizontal = makeCheckbox(autoScrollReverseHorizontal, title: MFLocalizedString("button-options.auto-scroll.reverse-horizontal", comment: ""))
        
        /// Grid
        func label(_ key: String) -> NSTextField { NSTextField(labelWithString: MFLocalizedString(key, comment: "")) }
        let reverseRow = NSStackView(views: [reverseVertical, reverseHorizontal])
        reverseRow.spacing = 16
        let grid = NSGridView(views: [
            [label("button-options.auto-scroll.acceleration"), acceleration.slider, acceleration.valueLabel],
            [label("button-options.auto-scroll.super-slowdown"), superSlowdown.slider, superSlowdown.valueLabel],
            [NSGridCell.emptyContentView, animateRelease, NSGridCell.emptyContentView],
            [label("button-options.auto-scroll.release-duration"), releaseDuration.slider, releaseDuration.valueLabel],
            [NSGridCell.emptyContentView, reverseRow, NSGridCell.emptyContentView],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 2).xPlacement = .leading
        grid.rowAlignment = .firstBaseline
        grid.columnSpacing = 8
        grid.rowSpacing = 8
        grid.row(at: 2).topPadding = 4
        grid.row(at: 4).topPadding = 4
        
        /// Section
        let separator = NSBox()
        separator.boxType = .separator
        let section = NSStackView(views: [separator, title, grid])
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 10
        section.setCustomSpacing(16, after: separator)
        section.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        view.addSubview(section)
        
        /// Insert between the 'lock pointer' hint and the Done button
        guard let doneTop = view.constraints.first(where: { ($0.firstItem as? NSButton) === doneButton && $0.firstAttribute == .top }),
              let hint = doneTop.secondItem as? NSView else {
            assert(false); return
        }
        doneTop.isActive = false
        NSLayoutConstraint.activate([
            section.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 16),
            section.leadingAnchor.constraint(equalTo: lockPointerButton.leadingAnchor),
            section.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            doneButton.topAnchor.constraint(equalTo: section.bottomAnchor, constant: 20),
        ])
    }
    
    private func makeSlider(_ configValue: ConfigValue<Double>, range: ClosedRange<Double>, step: Double, defaultValue: Double, format: @escaping (Double) -> String) -> (slider: NSSlider, valueLabel: NSTextField) {
        
        /// Updates the value label while dragging, but only writes the config when the user lets go (or uses the keyboard). Otherwise we'd commit the config (and notify the Helper) for every step of the drag.
        
        let slider = NSSlider(value: defaultValue, minValue: range.lowerBound, maxValue: range.upperBound, target: nil, action: nil)
        slider.isContinuous = true
        slider.widthAnchor.constraint(equalToConstant: 160).isActive = true
        
        let valueLabel = NSTextField(labelWithString: format(defaultValue))
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        
        configValue.producer.take(during: reactive.lifetime).startWithValues { [weak slider, weak valueLabel] value in
            slider?.doubleValue = value
            valueLabel?.stringValue = format(value)
        }
        slider.reactive.doubleValues.take(during: reactive.lifetime).observeValues { [weak valueLabel] rawValue in
            let value = (rawValue / step).rounded() * step
            valueLabel?.stringValue = format(value)
            if NSApp.currentEvent?.type != .leftMouseDragged {
                configValue.set(value)
            }
        }
        return (slider, valueLabel)
    }
    
    private func makeCheckbox(_ configValue: ConfigValue<Bool>, title: String) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        checkbox.reactive.boolValue <~ configValue
        configValue <~ checkbox.reactive.boolValues
        return checkbox
    }
    
    /// Interface
    
    @objc static func add() {
        
        /// Create new instance every time. Otherwise the done button won't be blue after the first open
        instance?.nibBundle?.unload()
        instance = nil
        instance = ButtonOptionsViewController(nibName: "ButtonOptionsViewController", bundle: Bundle.main)
        
        /// Open sheet
        guard let tabViewController = MainAppState.shared.tabViewController else { assert(false); return }
        tabViewController.presentAsSheet(instance!)
    }
    
    @objc static func remove() {
        
        /// Close sheet
        guard let tabViewController = MainAppState.shared.tabViewController else { assert(false); return }
        tabViewController.dismiss(instance!)
    }
    
    
    
}
