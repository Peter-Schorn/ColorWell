//
// ColorWellSegment.swift
// ColorWell
//

import Cocoa

/// A view that draws a segmented portion of a color well.
class ColorWellSegment: NSView {
    weak var colorWell: ColorWell?

    weak var layoutView: ColorWellLayoutView?

    private var cachedDefaultPath = CachedPath<NSBezierPath>()

    private var cachedShadowLayer: CALayer?

    /// A Boolean value that indicates whether the segment's
    /// color well is active.
    var isActive: Bool {
        colorWell?.isActive ?? false
    }

    /// A Boolean value that indicates whether the segment's
    /// color well is enabled.
    var isEnabled: Bool {
        colorWell?.isEnabled ?? false
    }

    /// The side containing this segment in its color well.
    var side: Side { .null }

    /// The segment's current state.
    var state = State.default {
        didSet {
            if needsDisplayOnStateChange(state) {
                needsDisplay = true
            }
        }
    }

    /// The unaltered fill color of the segment.
    var rawColor: NSColor {
        .colorWellSegmentColor
    }

    /// The color that is displayed directly in the segment,
    /// altered from `rawColor` to reflect whether the color
    /// well is currently enabled or disabled.
    var colorForDisplay: NSColor {
        isEnabled ? rawColor : rawColor.disabled
    }

    // MARK: Initializers

    /// Creates a segment for the given color well.
    init?(colorWell: ColorWell?, layoutView: ColorWellLayoutView?) {
        guard
            let colorWell,
            let layoutView
        else {
            return nil
        }
        super.init(frame: .zero)
        self.colorWell = colorWell
        self.layoutView = layoutView
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Dynamic Class Methods

    /// Invoked to perform a color well segment's action.
    @objc dynamic
    class func performAction(for segment: ColorWellSegment) -> Bool { false }

    // MARK: Dynamic Instance Methods

    /// Invoked to return whether the segment should be redrawn
    /// after its state changes.
    @objc dynamic
    func needsDisplayOnStateChange(_ state: State) -> Bool { false }
}

// MARK: Instance Methods
extension ColorWellSegment {
    /// Returns the default drawing path of the segment.
    func defaultPath(_ dirtyRect: NSRect) -> NSBezierPath {
        if cachedDefaultPath.bounds != dirtyRect {
            cachedDefaultPath = CachedPath(bounds: dirtyRect, side: side)
        }
        return cachedDefaultPath.path
    }

    /// Performs the segment's action.
    func performAction() -> Bool {
        Self.performAction(for: self)
    }

    /// Updates the shadow layer for the specified rectangle.
    func updateShadowLayer(_ dirtyRect: NSRect) {
        cachedShadowLayer?.removeFromSuperlayer()
        cachedShadowLayer = nil

        guard let layer else {
            return
        }

        let shadowRadius = 0.75
        let shadowOffset = CGSize(width: 0, height: -0.25)

        let shadowPath = CGPath.colorWellSegment(rect: dirtyRect, side: side)

        let maskPath = CGMutablePath()
        maskPath.addRect(
            dirtyRect.insetBy(
                dx: -(shadowRadius * 2) + shadowOffset.width,
                dy: -(shadowRadius * 2) + shadowOffset.height
            )
        )
        maskPath.addPath(shadowPath)
        maskPath.closeSubpath()

        let maskLayer = CAShapeLayer()
        maskLayer.path = maskPath
        maskLayer.fillRule = .evenOdd

        let shadowLayer = CALayer()
        shadowLayer.shadowRadius = shadowRadius
        shadowLayer.shadowOffset = shadowOffset
        shadowLayer.shadowPath = shadowPath
        shadowLayer.shadowOpacity = 0.5
        shadowLayer.mask = maskLayer

        layer.masksToBounds = false
        layer.addSublayer(shadowLayer)

        cachedShadowLayer = shadowLayer
    }
}

// MARK: Overrides
extension ColorWellSegment {
    override func draw(_ dirtyRect: NSRect) {
        colorForDisplay.setFill()
        defaultPath(dirtyRect).fill()
        updateShadowLayer(dirtyRect)
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        guard isEnabled else {
            return
        }
        state = .highlight
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        guard
            isEnabled,
            frameConvertedToWindow.contains(event.locationInWindow)
        else {
            return
        }
        _ = performAction()
    }
}

// MARK: Accessibility
extension ColorWellSegment {
    override func accessibilityParent() -> Any? {
        colorWell
    }

    override func accessibilityPerformPress() -> Bool {
        performAction()
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .button
    }

    override func isAccessibilityElement() -> Bool {
        true
    }
}

// MARK: - ColorWellSegment State

extension ColorWellSegment {
    /// A type that represents the state of a color well segment.
    @objc enum State: Int {
        /// The segment is being hovered over.
        case hover

        /// The segment is highlighted.
        case highlight

        /// The segment is pressed.
        case pressed

        /// The default, idle state of a segment.
        case `default`
    }
}

// MARK: - ColorWellSegment DraggingInformation

extension ColorWellSegment {
    /// Dragging information associated with a color well segment.
    struct DraggingInformation {
        /// The default values for this instance.
        private let defaults: (threshold: CGFloat, isDragging: Bool, offset: CGSize)

        /// The amount of movement that must occur before a dragging
        /// session can start.
        var threshold: CGFloat

        /// A Boolean value that indicates whether a drag is currently
        /// in progress.
        var isDragging: Bool

        /// The accumulated offset of the current series of dragging
        /// events.
        var offset: CGSize

        /// A Boolean value that indicates whether the current dragging
        /// information is valid for starting a dragging session.
        var isValid: Bool {
            hypot(offset.width, offset.height) >= threshold
        }

        /// Creates an instance with the given values.
        ///
        /// The values that are provided here will be cached, and used
        /// to reset the instance.
        init(
            threshold: CGFloat = 4,
            isDragging: Bool = false,
            offset: CGSize = CGSize()
        ) {
            self.defaults = (threshold, isDragging, offset)
            self.threshold = threshold
            self.isDragging = isDragging
            self.offset = offset
        }

        /// Resets the dragging information to its default values.
        mutating func reset() {
            self = DraggingInformation(
                threshold: defaults.threshold,
                isDragging: defaults.isDragging,
                offset: defaults.offset
            )
        }

        /// Updates the segment's dragging offset according to the x and y
        /// deltas of the given event.
        mutating func updateOffset(with event: NSEvent) {
            offset.width += event.deltaX
            offset.height += event.deltaY
        }
    }
}
