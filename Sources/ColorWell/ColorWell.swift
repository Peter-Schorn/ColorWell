//===----------------------------------------------------------------------===//
//
// ColorWell.swift
//
// Created: 2022. Author: Jordan Baird.
//
//===----------------------------------------------------------------------===//

import Cocoa
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - _ColorWellBaseView

/// A base view class that contains some default properties and methods
/// for use in the main `ColorWell` class.
public class _ColorWellBaseView: NSView {

  // MARK: Static Properties

  /// The default width for a color well's frame.
  internal static let defaultWidth: CGFloat = 64

  /// The default height for a color well's frame.
  internal static let defaultHeight: CGFloat = 28

  /// The default frame for a color well.
  internal static let defaultFrame = NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight)

  /// A base value to use when computing the width of lines drawn as
  /// part of a color well or its elements.
  internal static let lineWidth: CGFloat = 1

  /// The color shown by color wells that were not initialized with
  /// an initial value.
  ///
  /// Currently, this color is an RGBA white.
  internal static let defaultColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1)

  /// Hexadecimal codes used to construct the default colors shown in
  /// the color well's popover.
  internal static let defaultHexCodes = [
    "56C1FF", "72FDEA", "88FA4F", "FFF056", "FF968D", "FF95CA",
    "00A1FF", "15E6CF", "60D937", "FFDA31", "FF644E", "FF42A1",
    "0076BA", "00AC8E", "1FB100", "FEAE00", "ED220D", "D31876",
    "004D80", "006C65", "017101", "F27200", "B51800", "970E53",
    "FFFFFF", "D5D5D5", "929292", "5E5E5E", "000000",
  ]

  /// The default colors shown in the color well's popover.
  internal static let defaultSwatchColors = defaultHexCodes.compactMap {
    NSColor(hexString: $0)
  }
}

// MARK: _ColorWellBaseView Methods
extension _ColorWellBaseView {
  /// Returns a value for the given accessibility attribute,
  /// performing dynamic casting to the given type.
  private func provideAttributeValue<T>(
    ofType type: T.Type = T.self,
    for attribute: NSAccessibility.Attribute
  ) -> T? {
    provideValue(forAttribute: attribute) as? T
  }
  
  /// Returns a value for the given accessibility attribute.
  ///
  /// To be overridden by the main ``ColorWell`` class.
  @objc dynamic
  internal func provideValue(forAttribute attribute: NSAccessibility.Attribute) -> Any? { nil }

  /// Performs code for the given accessibility action.
  ///
  /// To be overridden by the main ``ColorWell`` class.
  @objc dynamic
  internal func performAction(forType type: NSAccessibility.Action) -> Bool { false }
}

// MARK: _ColorWellBaseView Overrides
extension _ColorWellBaseView {
  public override var alignmentRectInsets: NSEdgeInsets {
    .init(top: 2, left: 3, bottom: 2, right: 3)
  }

  public override var intrinsicContentSize: NSSize {
    Self.defaultFrame.size
  }

  public override func updateLayer() {
    let shadow = NSShadow()
    if NSApp.effectiveAppearanceIsDarkAppearance {
      shadow.shadowBlurRadius = Self.lineWidth / 2
      shadow.shadowColor = .shadowColor.withAlphaComponent(0.67)
    } else {
      shadow.shadowBlurRadius = Self.lineWidth
      shadow.shadowColor = .shadowColor.withAlphaComponent(0.5)
    }
    self.shadow = shadow
  }
}

// MARK: _ColorWellBaseView Accessibility
extension _ColorWellBaseView {
  public override func accessibilityChildren() -> [Any]? {
    provideAttributeValue(for: .children)
  }

  public override func accessibilityPerformPress() -> Bool {
    performAction(forType: .press)
  }

  public override func accessibilityRole() -> NSAccessibility.Role? {
    .colorWell
  }

  public override func accessibilityValue() -> Any? {
    provideAttributeValue(for: .value)
  }

  public override func isAccessibilityElement() -> Bool {
    true
  }

  public override func isAccessibilityEnabled() -> Bool {
    provideAttributeValue(for: .enabled) ?? true
  }
}

// MARK: - ColorWell

/// A view that displays a user-settable color value.
///
/// Color wells enable the user to select custom colors from within an app's
/// interface. A graphics app might, for example, include a color well to let
/// someone choose the fill color for a shape. Color wells display the currently
/// selected color, and interactions with the color well display interfaces
/// for selecting new colors.
public class ColorWell: _ColorWellBaseView {

  // MARK: Private/Internal Properties

  private var layoutView: ColorWellLayoutView!

  private var observations = [NSKeyValueObservation]()

  private var canSynchronizeColorPanel = true
  private var canExecuteChangeHandlers = true

  private var changeHandlers = Set<ChangeHandler>()

  private var sortedChangeHandlers: [ChangeHandler] {
    changeHandlers.sorted()
  }

  /// The segment that shows the color well's color.
  fileprivate var swatchSegment: SwatchSegment {
    layoutView.swatchSegment
  }

  /// The segment that toggles the color well's color panel.
  fileprivate var toggleSegment: ToggleSegment {
    layoutView.toggleSegment
  }

  /// The popover associated with the color well.
  fileprivate var popover: ColorWellPopover? {
    get { swatchSegment.popover }
    set { swatchSegment.popover = newValue }
  }

  // MARK: Public Properties

  /// The color panel controlled by the color well. Default value
  /// is `NSColorPanel.shared`.
  public var colorPanel = NSColorPanel.shared

  /// A Boolean value that indicates whether the color well's color panel
  /// allows adjusting the selected color's opacity. Default value is `true`.
  public var supportsOpacity = true

  /// A Boolean value that indicates whether the color well supports being
  /// included in group selections (using "Shift-click" functionality).
  public var allowsMultipleSelection = true

  /// The colors that will be shown as swatches in the color well's popover.
  ///
  /// The default values are defined according to the following hexadecimal
  /// codes:
  /// ```swift
  /// [
  ///     "56C1FF", "72FDEA", "88FA4F", "FFF056", "FF968D", "FF95CA",
  ///     "00A1FF", "15E6CF", "60D937", "FFDA31", "FF644E", "FF42A1",
  ///     "0076BA", "00AC8E", "1FB100", "FEAE00", "ED220D", "D31876",
  ///     "004D80", "006C65", "017101", "F27200", "B51800", "970E53",
  ///     "FFFFFF", "D5D5D5", "929292", "5E5E5E", "000000"
  /// ]
  /// ```
  /// ![Default swatches](grid-view)
  ///
  /// You can add and remove values to change the swatches that are displayed.
  ///
  /// ```swift
  /// let colorWell = ColorWell()
  /// colorWell.swatchColors += [
  ///     .systemPurple,
  ///     .controlColor,
  ///     .windowBackgroundColor
  /// ]
  /// colorWell.swatchColors.removeFirst()
  /// ```
  ///
  /// Whatever value this property holds at the time the user opens the color
  /// well's popover is the value that will be used to construct its swatches.
  /// Each popover is constructed lazily, so if this value changes between
  /// popover sessions, the next popover that is displayed will reflect the
  /// changes.
  ///
  /// - Note: If the array is empty, the color well's ``colorPanel`` will be
  ///   shown instead of a popover.
  public var swatchColors = defaultSwatchColors

  /// A Boolean value that indicates whether the color well is
  /// currently active.
  ///
  /// You can change this value using the ``activate(exclusive:)``
  /// and ``deactivate()`` methods.
  public var isActive: Bool {
    isEnabled && colorPanel.activeColorWells.contains(self)
  }

  /// A Boolean value that indicates whether the color well is enabled.
  ///
  /// If `false`, the color well will not react to mouse events, open
  /// its color panel, or show its popover.
  public var isEnabled: Bool = true {
    didSet {
      needsDisplay = true
    }
  }

  /// The color well's color.
  ///
  /// Setting this value immediately updates the visual state of both
  /// the color well and its color panel, and executes all change
  /// handlers stored by the color well.
  @objc dynamic
  public var color = ColorWell.defaultColor {
    didSet {
      if isActive {
        synchronizeColorPanel()
      }
      synchronizeSwatchSegment()
      executeChangeHandlers()
    }
  }

  // MARK: Initializers

  /// Creates a color well with the given frame rectangle and color.
  ///
  /// - Parameters:
  ///   - frameRect: The frame rectangle for the created color panel.
  ///   - color: The initial value of the color well's color.
  public init(frame frameRect: NSRect, color: NSColor) {
    super.init(frame: frameRect)
    sharedInit(color: color)
  }

  /// Creates a color well with the given frame rectangle.
  /// - Parameter frameRect: The frame rectangle for the created color panel.
  public override convenience init(frame frameRect: NSRect) {
    self.init(frame: frameRect, color: Self.defaultColor)
  }

  /// Creates a color well initialized to a default color and frame.
  public convenience init() {
    self.init(frame: Self.defaultFrame)
  }

  /// Creates a color well with the given color.
  /// - Parameter color: The initial value of the color well's color.
  public convenience init(color: NSColor) {
    self.init(frame: Self.defaultFrame, color: color)
  }

  /// Creates a color well with the given `CoreGraphics` color.
  /// - Parameter cgColor: The initial value of the color well's color.
  public convenience init?(cgColor: CGColor) {
    guard let color = NSColor(cgColor: cgColor) else {
      return nil
    }
    self.init(color: color)
  }

  /// Creates a color well with the given `CoreImage` color.
  /// - Parameter ciColor: The initial value of the color well's color.
  public convenience init(ciColor: CIColor) {
    self.init(color: .init(ciColor: ciColor))
  }

  #if canImport(SwiftUI)
  /// Creates a color well with the given `SwiftUI` color.
  /// - Parameter color: The initial value of the color well's color.
  @available(macOS 11.0, *)
  public convenience init(_ color: Color) {
    self.init(color: .init(color))
  }
  #endif

  /// Creates a color well from data in the given coder object.
  /// - Parameter coder: The coder object that contains the color
  ///   well's configuration details.
  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    sharedInit(color: Self.defaultColor)
  }
}

// MARK: ColorWell Private/Internal Methods
extension ColorWell {
  /// Iterates through the color well's stored change handlers,
  /// executing them in the order that they were created.
  private func executeChangeHandlers() {
    guard canExecuteChangeHandlers else {
      return
    }
    for handler in sortedChangeHandlers {
      handler(color)
    }
  }

  /// Inserts the change handlers in the given sequence into the
  /// color well's stored change handlers.
  internal func insertChangeHandlers(_ handlers: any Sequence<ChangeHandler>) {
    changeHandlers.formUnion(handlers)
  }

  /// Creates a series of key-value observations that work to keep
  /// the various aspects of the color well and its color panel in
  /// sync.
  private func setUpObservations() {
    observations = [
      colorPanel.observe(\.color, options: .new) { colorPanel, change in
        guard let newValue = change.newValue else {
          return
        }
        for colorWell in colorPanel.activeColorWells {
          colorWell.color = newValue
        }
      },

      colorPanel.observe(\.isVisible, options: .new) { [weak self] _, change in
        guard
          let self,
          let newValue = change.newValue
        else {
          return
        }
        if !newValue {
          self.deactivate()
        }
      },

      colorPanel.observe(\.showsAlpha, options: [.initial, .new]) { [weak self] colorPanel, change in
        guard
          let self,
          let newValue = change.newValue
        else {
          return
        }
        if newValue != self.supportsOpacity {
          colorPanel.showsAlpha = self.supportsOpacity
        }
      },
    ]
  }

  /// Shared code to execute on a color well's initialization.
  private func sharedInit(color: NSColor) {
    layoutView = .init(colorWell: self)

    addSubview(layoutView)

    layoutView.translatesAutoresizingMaskIntoConstraints = false
    layoutView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    layoutView.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
    layoutView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    layoutView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

    withoutExecutingChangeHandlers { colorWell in
      colorWell.withoutSynchronizingColorPanel { colorWell in
        colorWell.color = color
      }
    }
  }

  /// Sets the color panel's color to be equal to the color
  /// well's color.
  internal func synchronizeColorPanel() {
    guard
      canSynchronizeColorPanel,
      colorPanel.color != color
    else {
      return
    }
    if colorPanel.activeColorWells.subtracting([self]).isEmpty {
      colorPanel.color = color
    } else {
      color = colorPanel.color
    }
  }

  /// Sets the swatch segment's fill color to be equal to the
  /// color well's color.
  private func synchronizeSwatchSegment() {
    if swatchSegment.fillColor != color {
      swatchSegment.fillColor = color
    }
  }
  
  /// Performs a block of code, ensuring that the color well's
  /// change handlers are not executed.
  internal func withoutExecutingChangeHandlers<T>(
    execute block: (ColorWell) throws -> T
  ) rethrows -> T {
    canExecuteChangeHandlers = false
    defer {
      canExecuteChangeHandlers = true
    }
    return try block(self)
  }

  /// Performs a block of code, ensuring that the color panel is
  /// not synchronized.
  internal func withoutSynchronizingColorPanel<T>(
    execute block: (ColorWell) throws -> T
  ) rethrows -> T {
    canSynchronizeColorPanel = false
    defer {
      canSynchronizeColorPanel = true
    }
    return try block(self)
  }
}

// MARK: ColorWell Public Methods
extension ColorWell {
  /// Activates the color well and displays its color panel.
  ///
  /// Both elements will remain synchronized until either the color panel
  /// is closed, or the color well is deactivated.
  ///
  /// - Parameter exclusive: If this value is `true`, all other active
  ///   color wells attached to this color well's color panel will be
  ///   deactivated.
  public func activate(exclusive: Bool) {
    guard isEnabled else {
      return
    }

    if exclusive {
      for colorWell in colorPanel.activeColorWells where colorWell !== self {
        colorWell.deactivate()
      }
    }

    synchronizeColorPanel()
    colorPanel.activeColorWells.insert(self)
    colorPanel.orderFront(self)
    setUpObservations()
  }

  /// Deactivates the color well, detaching it from its color panel.
  ///
  /// Until the color well is activated again, changes to its color
  /// panel will not affect its state.
  public func deactivate() {
    colorPanel.activeColorWells.remove(self)
    toggleSegment.state = .default
    observations.removeAll()
  }

  /// Adds an action to perform when the color well's color changes.
  ///
  /// ```swift
  /// let colorWell = ColorWell()
  /// let textView = NSTextView()
  /// // ...
  /// // ...
  /// // ...
  /// colorWell.onColorChange { color in
  ///     textView.textColor = color
  /// }
  /// ```
  ///
  /// - Parameter action: A block of code that will be executed when
  ///   the color well's color changes.
  public func onColorChange(perform action: @escaping (NSColor) -> Void) {
    changeHandlers.insert(ChangeHandler(handler: action))
  }
}

// MARK: ColorWell Overrides
extension ColorWell {
  internal override func provideValue(forAttribute attribute: NSAccessibility.Attribute) -> Any? {
    switch attribute {
    case .children:
      return [toggleSegment]
    case .enabled:
      return isEnabled
    case .value:
      return color.createAccessibilityValue()
    default:
      return nil
    }
  }

  internal override func performAction(forType type: NSAccessibility.Action) -> Bool {
    switch type {
    case .press:
      swatchSegment.performAction()
      return true
    default:
      return false
    }
  }
}

// MARK: ColorWell Deprecated
extension ColorWell {
  /// Activates the color well and displays its color panel.
  ///
  /// Both elements will remain synchronized until either the color panel
  /// is closed, or the color well is deactivated.
  ///
  /// - Parameter exclusive: If this value is `true`, all other active
  ///   color wells attached to this color well's color panel will be
  ///   deactivated.
  @available(*, deprecated, message: "Renamed to 'activate(exclusive:)'", renamed: "activate(exclusive:)")
  public func activate(_ exclusive: Bool) {
    activate(exclusive: exclusive)
  }

  /// Adds an action to perform when the color well's color changes.
  ///
  /// ```swift
  /// let colorWell = ColorWell()
  /// let textView = NSTextView()
  /// // ...
  /// // ...
  /// // ...
  /// colorWell.observeColor { color in
  ///     textView.textColor = color
  /// }
  /// ```
  ///
  /// - Parameter handler: A block of code that will be executed when
  ///   the color well's color changes.
  @available(*, deprecated, message: "Renamed to 'onColorChange(perform:)'", renamed: "onColorChange(perform:)")
  public func observeColor(onChange handler: @escaping (NSColor) -> Void) {
    onColorChange(perform: handler)
  }
}

// MARK: - ColorWellLayoutView

/// A grid view that displays color well segments side by side.
class ColorWellLayoutView: NSGridView {
  /// A segment that displays a color swatch with the color well's
  /// current color selection.
  let swatchSegment: SwatchSegment

  /// A segment that, when pressed, opens the color well's color panel.
  let toggleSegment: ToggleSegment

  /// This layer helps the color well mimic the appearance of a native
  /// macOS UI element by drawing a small bezel around the edge of the view.
  private var bezelLayer: CAGradientLayer?

  /// Creates a grid view with the given color well.
  init(colorWell: ColorWell) {
    swatchSegment = .init(colorWell: colorWell)
    toggleSegment = .init(colorWell: colorWell)
    super.init(frame: .zero)
    wantsLayer = true
    columnSpacing = 0
    xPlacement = .fill
    yPlacement = .fill
    addRow(with: [swatchSegment, toggleSegment])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: ColorWellLayoutView Overrides
extension ColorWellLayoutView {
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    bezelLayer?.removeFromSuperlayer()

    guard let layer else {
      return
    }

    let bezelLayer = CAGradientLayer()
    bezelLayer.colors = [
      CGColor.clear,
      CGColor.clear,
      CGColor.clear,
      CGColor(gray: 1, alpha: 0.125),
    ]
    bezelLayer.needsDisplayOnBoundsChange = true
    bezelLayer.frame = layer.bounds

    let bezelFrame = bezelLayer.frame.insetBy(
      dx: ColorWell.lineWidth / 2,
      dy: ColorWell.lineWidth / 2)

    let maskLayer = CAShapeLayer()
    maskLayer.fillColor = .clear
    maskLayer.strokeColor = .black
    maskLayer.lineWidth = ColorWell.lineWidth
    maskLayer.needsDisplayOnBoundsChange = true
    maskLayer.frame = bezelLayer.frame
    maskLayer.path = .colorWellPath(rect: bezelFrame)

    bezelLayer.mask = maskLayer

    layer.addSublayer(bezelLayer)
    bezelLayer.zPosition += 1
    self.bezelLayer = bezelLayer
  }
}

// MARK: - ColorWellSegment

class ColorWellSegment: NSView {
  weak var colorWell: ColorWell?

  private var appearanceObservation: NSKeyValueObservation?

  private var trackingArea: NSTrackingArea?

  private var draggingOffset = CGSize()

  var isActive: Bool {
    colorWell?.isActive ?? false
  }

  var isValidDrag: Bool {
    max(abs(draggingOffset.width), abs(draggingOffset.height)) >= 2
  }

  var state = State.default {
    didSet {
      switch oldValue {
      case .hover:
        removeHoverIndicator()
      case .highlight:
        removeHighlightIndicator()
      case .pressed:
        removePressedIndicator()
      case .default:
        break
      }
      switch state {
      case .hover:
        drawHoverIndicator()
      case .highlight:
        drawHighlightIndicator()
      case .pressed:
        drawPressedIndicator()
      case .default:
        break
      }
    }
  }

  var side: Side { .null }

  /// The color well's current height.
  var colorWellHeight: CGFloat {
    colorWell?.frame.height ?? ColorWell.defaultHeight
  }

  /// A Boolean value that indicates whether the color well is enabled.
  var colorWellIsEnabled: Bool {
    colorWell?.isEnabled ?? false
  }

  /// The default fill color of the segment.
  var defaultFillColor: NSColor { .buttonColor }

  /// The unaltered fill color of the segment. Setting this value
  /// automatically redraws the segment.
  lazy var fillColor = defaultFillColor {
    didSet {
      needsDisplay = true
    }
  }

  /// The color that is displayed directly in the segment, altered
  /// from `fillColor` to reflect whether the color well is currently
  /// enabled or disabled.
  var displayColor: NSColor {
    if colorWellIsEnabled {
      return fillColor
    } else {
      let disabledAlpha = max(fillColor.alphaComponent - 0.5, 0.1)
      return fillColor.withAlphaComponent(disabledAlpha)
    }
  }

  init(colorWell: ColorWell) {
    super.init(frame: .zero)
    self.colorWell = colorWell
    if #available(macOS 10.14, *) {
      appearanceObservation = NSApp.observe(
        \.effectiveAppearance,
         options: .new
      ) { [weak self] _, _ in
        self?.needsDisplay = true
      }
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: ColorWellSegment Dynamic Methods

  @objc dynamic
  func drawHoverIndicator() { }

  @objc dynamic
  func removeHoverIndicator() { }

  @objc dynamic
  func drawHighlightIndicator() {
    if #available(macOS 10.14, *) {
      fillColor = defaultFillColor.withSystemEffect(.rollover)
    } else if let blendedColor = defaultFillColor.blended(withFraction: 0.25, of: .black) {
      fillColor = blendedColor
    }
  }

  @objc dynamic
  func removeHighlightIndicator() {
    fillColor = defaultFillColor
  }

  @objc dynamic
  func drawPressedIndicator() {
    if #available(macOS 10.14, *) {
      switch NSColor.currentControlTint {
      case .graphiteControlTint:
        // The graphite control color is almost indistinguishable
        // from the button color, so give it a "pressed" effect to
        // make it more pronounced.
        fillColor = .controlAccentColor.withSystemEffect(.pressed)
      default:
        fillColor = .controlAccentColor
      }
    } else if let blendedColor = fillColor.blended(withFraction: 0.25, of: .white) {
      fillColor = blendedColor
    }
  }

  @objc dynamic
  func removePressedIndicator() {
    fillColor = defaultFillColor
  }

  @objc dynamic
  func performAction() { }
}

// MARK: ColorWellSegment Private/Internal Methods
extension ColorWellSegment {
  /// Returns the default path that will be used to draw the segment.
  func defaultPath(for rect: NSRect) -> NSBezierPath {
    .colorWellSegment(rect: rect, side: side)
  }

  private func updateDraggingOffset(with event: NSEvent) {
    draggingOffset.width += event.deltaX
    draggingOffset.height += event.deltaY
  }

  private func resetDraggingOffset() {
    draggingOffset = .zero
  }
}

// MARK: ColorWellSegment Overrides
extension ColorWellSegment {
  override func draw(_ dirtyRect: NSRect) {
    displayColor.setFill()
    defaultPath(for: dirtyRect).fill()
  }

  override func mouseEntered(with event: NSEvent) {
    super.mouseEntered(with: event)
    guard colorWellIsEnabled else {
      return
    }
    if state == .default {
      state = .hover
    }
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
    guard colorWellIsEnabled else {
      return
    }
    if state == .hover {
      state = .default
    }
  }

  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
    guard colorWellIsEnabled else {
      return
    }
    state = .highlight
  }

  override func mouseUp(with event: NSEvent) {
    super.mouseUp(with: event)
    resetDraggingOffset()
    guard
      colorWellIsEnabled,
      frameConvertedToWindow.contains(event.locationInWindow)
    else {
      return
    }
    performAction()
  }

  override func mouseDragged(with event: NSEvent) {
    super.mouseDragged(with: event)

    guard colorWellIsEnabled else {
      return
    }

    updateDraggingOffset(with: event)

    guard
      !isActive,
      isValidDrag
    else {
      return
    }

    if frameConvertedToWindow.contains(event.locationInWindow) {
      state = .highlight
    } else {
      state = .default
    }
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingArea {
      removeTrackingArea(trackingArea)
    }
    trackingArea = .init(
      rect: bounds,
      options: [
        .activeInKeyWindow,
        .mouseEnteredAndExited,
      ],
      owner: self)
    // Force unwrap is fine, as we just set this value.
    addTrackingArea(trackingArea!)
  }
}

// MARK: ColorWellSegment Accessibility
extension ColorWellSegment {
  override func accessibilityParent() -> Any? {
    colorWell
  }

  override func accessibilityPerformPress() -> Bool {
    performAction()
    return true
  }

  override func accessibilityRole() -> NSAccessibility.Role? {
    .button
  }

  override func isAccessibilityElement() -> Bool {
    true
  }
}

// MARK: State
extension ColorWellSegment {
  enum State {
    case hover
    case highlight
    case pressed
    case `default`
  }
}

// MARK: - ToggleSegment

class ToggleSegment: ColorWellSegment {
  private var imageLayer: CALayer?

  override var side: Side { .right }

  override init(colorWell: ColorWell) {
    super.init(colorWell: colorWell)
    // Constraining this segment's width will force
    // the other segment to fill the remaining space.
    translatesAutoresizingMaskIntoConstraints = false
    widthAnchor.constraint(equalToConstant: 20).isActive = true
  }
}

// MARK: ToggleSegment Methods
extension ToggleSegment {
  /// Adds a layer that contains an image indicating that the
  /// segment opens the color panel.
  private func setImageLayer(clip: Bool = false) {
    imageLayer?.removeFromSuperlayer()

    wantsLayer = true
    guard let layer else {
      return
    }

    // Force unwrap is okay here, as the image ships with Cocoa.
    var image = NSImage(named: NSImage.touchBarColorPickerFillName)!

    if state == .highlight {
      image = image.tinted(to: .white, amount: 0.33)
    }

    let dimension = min(layer.bounds.width, layer.bounds.height) - 5
    let imageLayer = CALayer()

    imageLayer.frame = .init(
      x: 0,
      y: 0,
      width: dimension,
      height: dimension
    ).centered(in: layer.bounds)
    imageLayer.contents = clip ? image.clippedToCircle() : image

    if !colorWellIsEnabled {
      imageLayer.opacity = 0.5
    }

    layer.addSublayer(imageLayer)
    self.imageLayer = imageLayer
  }
}

// MARK: ToggleSegment Overrides
extension ToggleSegment {
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    setImageLayer(clip: true)
  }

  override func performAction() {
    guard let colorWell else {
      return
    }
    if colorWell.isActive {
      colorWell.deactivate()
      state = .default
    } else {
      let exclusive = !(NSEvent.modifierFlags.contains(.shift) && colorWell.allowsMultipleSelection)
      colorWell.activate(exclusive: exclusive)
      state = .pressed
    }
  }
}

// MARK: ToggleSegment Accessibility
extension ToggleSegment {
  override func accessibilityLabel() -> String? {
    "color picker"
  }
}

// MARK: - SwatchSegment

class SwatchSegment: ColorWellSegment {
  private var caretView: CaretView?

  private var canShowPopover = false

  fileprivate var popover: ColorWellPopover?

  override var side: Side { .left }

  override var displayColor: NSColor {
    super.displayColor.sRGB
  }

  private var borderColor: NSColor {
    let alpha = min(
      min(
        displayColor.averageBrightness,
        displayColor.alphaComponent),
      0.2)
    return NSColor(white: 1, alpha: alpha)
  }

  private var overrideShowPopover: Bool {
    colorWell?.swatchColors.isEmpty ?? false
  }

  override init(colorWell: ColorWell) {
    super.init(colorWell: colorWell)
    registerForDraggedTypes([.color])
  }
}

// MARK: SwatchSegment Methods
extension SwatchSegment {
  func prepareForPopover() {
    guard !overrideShowPopover else {
      return
    }
    canShowPopover = popover == nil
  }

  private func makePopover() -> ColorWellPopover? {
    if let colorWell {
      return .init(colorWell: colorWell)
    }
    return nil
  }

  private func makeAndShowPopover() {
    // The popover should be nil no matter what here.
    assert(popover == nil, "Popover should not exist yet")
    popover = makePopover()
    guard let popover else {
      return
    }
    // The popover _shouldn't_ be shown, but check for it just in case.
    if popover.isShown {
      popover.close()
    } else {
      popover.show(relativeTo: frame, of: self, preferredEdge: .minY)
    }
  }

  private func setDraggingFrame(for draggingItem: NSDraggingItem) {
    guard let colorWell else {
      return
    }
    let draggingFrame = NSRect(x: 0, y: 0, width: 12, height: 12)
    let draggingImage = NSImage(color: colorWell.color, size: draggingFrame.size, radius: 2)

    draggingItem.setDraggingFrame(draggingFrame, contents: draggingImage)
  }
}

// MARK: SwatchSegment Overrides
extension SwatchSegment {
  override func draw(_ dirtyRect: NSRect) {
    guard colorWellIsEnabled else {
      super.draw(dirtyRect)
      return
    }

    NSImage.drawSwatch(
      with: displayColor,
      in: dirtyRect,
      clippingTo: defaultPath(for: dirtyRect))

    borderColor.setStroke()
    let borderPath = defaultPath(for: dirtyRect.insetBy(dx: 0.125, dy: 0.25))
    borderPath.lineWidth = 0.5
    borderPath.stroke()
  }

  override func drawHoverIndicator() {
    guard !overrideShowPopover else {
      return
    }
    let caretView = CaretView()
    addSubview(caretView)
    caretView.trailingAnchor.constraint(
      equalTo: trailingAnchor,
      constant: -2.5
    ).isActive = true
    caretView.centerYAnchor.constraint(
      equalTo: centerYAnchor
    ).isActive = true
    self.caretView = caretView
  }

  override func removeHoverIndicator() {
    // Ensure the caret view is removed, regardless
    // of whether `overrideShowPopover` is true.
    caretView?.removeFromSuperview()
    caretView = nil
  }

  override func drawHighlightIndicator() { }

  override func removeHighlightIndicator() { }

  override func drawPressedIndicator() { }

  override func removePressedIndicator() { }

  override func performAction() {
    prepareForPopover()
    if overrideShowPopover {
      colorWell?.toggleSegment.state = .pressed
      colorWell?.toggleSegment.performAction()
    } else if canShowPopover {
      makeAndShowPopover()
    }
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    // Ignore any subviews the segment may contain
    // (i.e. the caret view).
    frame.contains(point) ? self : nil
  }

  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
    state = .hover
  }

  override func mouseDragged(with event: NSEvent) {
    super.mouseDragged(with: event)

    guard isValidDrag else {
      return
    }

    state = .default

    let pasteboardItem = NSPasteboardItem()
    pasteboardItem.setDataProvider(self, forTypes: [.color])

    let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
    setDraggingFrame(for: draggingItem)

    beginDraggingSession(with: [draggingItem], event: event, source: self)
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard
      let types = sender.draggingPasteboard.types,
      types.contains(where: { registeredDraggedTypes.contains($0) })
    else {
      return []
    }
    return .move
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    guard
      let data = sender.draggingPasteboard.data(forType: .color),
      let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    else {
      return false
    }
    colorWell?.color = color
    return true
  }
}

// MARK: SwatchSegment Accessibility
extension SwatchSegment {
  override func isAccessibilityElement() -> Bool {
    false
  }
}

// MARK: SwatchSegment NSDraggingSource
extension SwatchSegment: NSDraggingSource {
  func draggingSession(
    _ session: NSDraggingSession,
    sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    .move
  }
}

// MARK: SwatchSegment NSPasteboardItemDataProvider
extension SwatchSegment: NSPasteboardItemDataProvider {
  func pasteboard(
    _ pasteboard: NSPasteboard?,
    item: NSPasteboardItem,
    provideDataForType type: NSPasteboard.PasteboardType
  ) {
    guard
      type == .color,
      let color = colorWell?.color,
      let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
    else {
      return
    }
    item.setData(data, forType: type)
  }
}

// MARK: CaretView
extension SwatchSegment {
  /// A view that contains a downward-facing caret inside of a translucent
  /// circle. This view appears when the mouse hovers over a swatch segment.
  class CaretView: NSImageView {
    /// An image of a downward-facing caret inside of a translucent circle.
    private var caretImage: NSImage {
      let sizeConstant: CGFloat = 12
      return .init(
        size: .init(width: sizeConstant, height: sizeConstant),
        flipped: false
      ) { bounds in
        let circlePath = NSBezierPath(ovalIn: bounds)
        NSColor(
          srgbRed: 0.235,
          green: 0.235,
          blue: 0.235,
          alpha: 0.4
        ).setFill()
        circlePath.fill()

        let caretPathBounds = NSRect(
          x: 0,
          y: 0,
          width: sizeConstant / 2,
          height: sizeConstant / 4
        ).centered(in: bounds)

        let caretPath = NSBezierPath()
        caretPath.lineWidth = 1.5
        caretPath.lineCapStyle = .round
        caretPath.move(
          to: .init(
            x: caretPathBounds.minX,
            y: caretPathBounds.maxY - (caretPath.lineWidth / 4)))
        caretPath.line(
          to: .init(
            x: caretPathBounds.midX,
            y: caretPathBounds.minY - (caretPath.lineWidth / 4)))
        caretPath.line(
          to: .init(
            x: caretPathBounds.maxX,
            y: caretPathBounds.maxY - (caretPath.lineWidth / 4)))

        NSColor.white.setStroke()
        caretPath.stroke()

        return true
      }
    }

    init() {
      super.init(frame: .zero)
      image = caretImage
      translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }
}

// MARK: - ColorWellPopover

/// A popover that contains a grid of selectable color swatches.
class ColorWellPopover: NSPopover {
  weak var colorWell: ColorWell?

  /// The popover's content view controller.
  let popoverViewController: ColorWellPopoverViewController

  /// The swatches that are shown in the popover.
  var swatches: [ColorSwatch] {
    popoverViewController.swatches
  }

  /// Creates a popover for the given color well.
  init(colorWell: ColorWell) {
    popoverViewController = .init(colorWell: colorWell)
    super.init()
    self.colorWell = colorWell
    contentViewController = popoverViewController
    behavior = .transient
    delegate = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func show(
    relativeTo positioningRect: NSRect,
    of positioningView: NSView,
    preferredEdge: NSRectEdge
  ) {
    super.show(
      relativeTo: positioningRect,
      of: positioningView,
      preferredEdge: preferredEdge)
    guard
      let color = colorWell?.color,
      let swatch = swatches.first(where: { $0.color.resembles(color) })
    else {
      return
    }
    swatch.select()
  }
}

// MARK: ColorWellPopover NSPopoverDelegate
extension ColorWellPopover: NSPopoverDelegate {
  func popoverDidClose(_ notification: Notification) {
    // Async so that ColorWellSegment's mouseDown method
    // has a chance to run before the popover becomes nil.
    DispatchQueue.main.async { [weak colorWell] in
      colorWell?.popover = nil
    }
  }
}

// MARK: - ColorWellPopoverViewController

/// A view controller that controls a view that contains a grid
/// of selectable color swatches.
class ColorWellPopoverViewController: NSViewController {
  var containerView: ColorWellPopoverContainerView {
    didSet {
      synchronize()
    }
  }

  var swatches: [ColorSwatch] {
    containerView.swatches
  }

  init(colorWell: ColorWell) {
    containerView = .init(colorWell: colorWell)
    super.init(nibName: nil, bundle: nil)
    synchronize()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func synchronize() {
    view = containerView
  }
}

// MARK: - ColorWellPopoverContainerView

/// A view that contains a grid of selectable color swatches.
class ColorWellPopoverContainerView: NSView {
  var layoutView: ColorWellPopoverLayoutView?

  var swatches: [ColorSwatch] {
    layoutView?.swatches ?? []
  }

  init(colorWell: ColorWell) {
    super.init(frame: .zero)

    let layoutView = ColorWellPopoverLayoutView(containerView: self, colorWell: colorWell)
    addSubview(layoutView)

    // Center the layout view inside the container.
    layoutView.translatesAutoresizingMaskIntoConstraints = false
    layoutView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    layoutView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

    // Give the container a 20px padding.
    translatesAutoresizingMaskIntoConstraints = false
    widthAnchor.constraint(
      equalTo: layoutView.widthAnchor,
      constant: 20
    ).isActive = true
    heightAnchor.constraint(
      equalTo: layoutView.heightAnchor,
      constant: 20
    ).isActive = true

    self.layoutView = layoutView
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: ColorWellPopoverContainerView Accessibility
extension ColorWellPopoverContainerView {
  override func accessibilityChildren() -> [Any]? {
    layoutView.map { [$0] }
  }

  override func accessibilityRole() -> NSAccessibility.Role? {
    .group
  }
}

// MARK: - ColorWellPopoverLayoutView

/// A view that provides the layout for a popover's color swatches.
class ColorWellPopoverLayoutView: NSGridView {
  weak var containerView: ColorWellPopoverContainerView?
  let maxItemsPerRow: Int
  private(set) var swatches = [ColorSwatch]()

  var selectedSwatch: ColorSwatch? {
    swatches.first { $0.isSelected }
  }

  /// Creates a layout view with the given container view and color well,
  /// using the color well's `swatchColors` property to construct a grid
  /// of swatches.
  init(
    containerView: ColorWellPopoverContainerView,
    colorWell: ColorWell
  ) {
    self.containerView = containerView
    let swatchCount = colorWell.swatchColors.count
    self.maxItemsPerRow = max(4, Int(sqrt(Double(swatchCount)).rounded(.up)))

    super.init(frame: .zero)
    rowSpacing = 1
    columnSpacing = 1

    let rowCount = Int((Double(swatchCount) / Double(maxItemsPerRow)).rounded(.up))
    swatches = colorWell.swatchColors.map {
      .init(rowCount: rowCount, color: $0, colorWell: colorWell, layoutView: self)
    }

    for row in makeRows() {
      addRow(with: row)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: ColorWellPopoverLayoutView Methods
extension ColorWellPopoverLayoutView {
  /// Converts the view's swatches into rows.
  private func makeRows() -> [[ColorSwatch]] {
    var currentRow = [ColorSwatch]()
    var rows = [[ColorSwatch]]()
    for swatch in swatches {
      if currentRow.count >= maxItemsPerRow {
        rows.append(currentRow)
        currentRow.removeAll()
      }
      currentRow.append(swatch)
    }
    if !currentRow.isEmpty {
      rows.append(currentRow)
    }
    return rows
  }
}

// MARK: ColorWellPopoverLayoutView Overrides
extension ColorWellPopoverLayoutView {
  override func mouseDragged(with event: NSEvent) {
    super.mouseDragged(with: event)
    let swatch = swatches.first {
      $0.frameConvertedToWindow.contains(event.locationInWindow)
    }
    swatch?.select()
  }

  override func mouseUp(with event: NSEvent) {
    super.mouseUp(with: event)
    selectedSwatch?.performAction()
  }
}

// MARK: ColorWellPopoverLayoutView Accessibility
extension ColorWellPopoverLayoutView {
  override func accessibilityParent() -> Any? {
    containerView
  }

  override func accessibilityChildren() -> [Any]? {
    swatches
  }

  override func accessibilityRole() -> NSAccessibility.Role? {
    .layoutArea
  }
}

// MARK: - ColorSwatch

/// A rectangular, clickable color swatch that is displayed inside
/// of a color well's popover.
///
/// When a swatch is clicked, the color well's color value is set
/// to the color value of the swatch.
class ColorSwatch: NSView {
  weak var layoutView: ColorWellPopoverLayoutView?
  let colorWell: ColorWell
  let color: NSColor

  private var bezelLayer: CAShapeLayer?
  private let borderWidth: CGFloat = 2
  private let cornerRadius: CGFloat = 1

  /// A Boolean value that indicates whether the swatch is selected.
  ///
  /// In most cases, this value is true if the swatch's color matches
  /// the color value of its respective color well. However, setting
  /// this value does not automatically update the color well, although
  /// it does automatically highlight the swatch and unhighlight its
  /// siblings.
  private(set) var isSelected = false {
    didSet {
      guard oldValue != isSelected else {
        return
      }
      defer {
        updateBezel()
      }
      guard isSelected else {
        return
      }
      iterateOtherSwatches(where: [\.isSelected]) {
        $0.isSelected = false
      }
    }
  }

  /// The computed border color of the swatch, created based on its
  /// current color.
  private var borderColor: CGColor {
    .init(gray: (1 - color.averageBrightness) / 4, alpha: 0.15)
  }

  /// The computed bezel color of the swatch.
  /// - Note: Currently, this color is always white.
  private var bezelColor: CGColor { .white }

  /// Creates a swatch with the given color, color well, and layout view.
  init(
    rowCount: Int,
    color: NSColor,
    colorWell: ColorWell,
    layoutView: ColorWellPopoverLayoutView
  ) {
    self.color = color
    self.colorWell = colorWell
    self.layoutView = layoutView
    let size = Self.size(forRowCount: rowCount)
    super.init(frame: .init(origin: .zero, size: size))
    wantsLayer = true
    translatesAutoresizingMaskIntoConstraints = false
    widthAnchor.constraint(equalToConstant: size.width).isActive = true
    heightAnchor.constraint(equalToConstant: size.height).isActive = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: ColorSwatch Static Methods
extension ColorSwatch {
  /// Returns the correct size for a swatch based on the row count that
  /// is passed into it. Bigger row counts result in smaller swatches.
  static func size(forRowCount rowCount: Int) -> CGSize {
    if rowCount < 6 {
      return .init(width: 37, height: 20)
    } else if rowCount < 10 {
      return .init(width: 31, height: 18)
    }
    return .init(width: 15, height: 15)
  }
}

// MARK: ColorSwatch Methods
extension ColorSwatch {
  /// Returns all swatches in the layout view that match the given
  /// conditions.
  private func swatches(
    matching conditions: any Collection<(ColorSwatch) -> Bool>
  ) -> [ColorSwatch] {
    guard let layoutView else {
      return []
    }
    return layoutView.swatches.filter { swatch in
      conditions.allSatisfy { condition in
        condition(swatch)
      }
    }
  }

  /// Iterates through all other swatches in the layout view and
  /// executes the given block of code, provided a set of conditions
  /// are met.
  private func iterateOtherSwatches(
    where conditions: any Collection<(ColorSwatch) -> Bool>,
    block: (ColorSwatch) -> Void
  ) {
    let conditions = conditions + [{ $0 !== self }]
    for swatch in swatches(matching: conditions) {
      block(swatch)
    }
  }

  /// Updates the swatch's border according to the current value of
  /// the swatch's `isSelected` property.
  private func updateBorder() {
    layer?.borderWidth = borderWidth
    if isSelected {
      layer?.borderColor = bezelColor
    } else {
      layer?.borderColor = borderColor
    }
  }

  /// Draws a rounded bezel around the swatch, if the swatch is
  /// selected. If the swatch is not selected, its border is updated
  /// and the method returns early.
  private func updateBezel() {
    bezelLayer?.removeFromSuperlayer()
    bezelLayer = nil

    guard
      let layer,
      isSelected
    else {
      updateBorder()
      return
    }
    let bezelLayer = CAShapeLayer()

    bezelLayer.masksToBounds = false
    bezelLayer.frame = layer.bounds

    bezelLayer.path = .init(
      roundedRect: layer.bounds,
      cornerWidth: cornerRadius,
      cornerHeight: cornerRadius,
      transform: nil)

    bezelLayer.fillColor = .clear
    bezelLayer.strokeColor = bezelColor
    bezelLayer.lineWidth = borderWidth

    bezelLayer.shadowColor = NSColor.shadowColor.cgColor
    bezelLayer.shadowRadius = 0.5
    bezelLayer.shadowOpacity = 0.25
    bezelLayer.shadowOffset = .zero

    bezelLayer.shadowPath = .init(
      roundedRect: layer.bounds.insetBy(dx: borderWidth, dy: borderWidth),
      cornerWidth: cornerRadius,
      cornerHeight: cornerRadius,
      transform: nil
    ).copy(
      strokingWithWidth: borderWidth,
      lineCap: .round,
      lineJoin: .round,
      miterLimit: 0)

    layer.addSublayer(bezelLayer)
    layer.masksToBounds = false
    layer.borderColor = bezelColor
    layer.borderWidth = borderWidth

    self.bezelLayer = bezelLayer
  }

  /// Selects the swatch, drawing a bezel around its edges and ensuring
  /// that all other swatches in the layout view are deselected.
  func select() {
    // Setting the `isSelected` property automatically highlights the
    // swatch and unhighlights all other swatches in the layout view.
    isSelected = true
  }

  /// Performs the swatch's action, setting the color well's color to
  /// that of the swatch, and closing the popover.
  func performAction() {
    if colorWell.isActive {
      colorWell.withoutSynchronizingColorPanel {
        $0.color = color
      }
      colorWell.withoutExecutingChangeHandlers {
        $0.synchronizeColorPanel()
      }
    } else {
      colorWell.color = color
    }
    colorWell.popover?.close()
  }
}

// MARK: ColorSwatch Overrides
extension ColorSwatch {
  override func draw(_ dirtyRect: NSRect) {
    color.sRGB.drawSwatch(in: dirtyRect)
    updateBorder()
  }

  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
    select()
  }
}

// MARK: ColorSwatch Accessibility
extension ColorSwatch {
  override func accessibilityLabel() -> String? {
    "color swatch"
  }

  override func accessibilityParent() -> Any? {
    layoutView
  }

  override func accessibilityPerformPress() -> Bool {
    performAction()
    return true
  }

  override func accessibilityRole() -> NSAccessibility.Role? {
    .button
  }

  override func isAccessibilityElement() -> Bool {
    true
  }

  override func isAccessibilitySelected() -> Bool {
    isSelected
  }
}
