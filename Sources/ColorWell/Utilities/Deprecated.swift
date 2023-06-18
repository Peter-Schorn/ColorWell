//
// Deprecated.swift
// ColorWell
//

import Cocoa

// MARK: - ColorWell

extension ColorWell {
    /// The color panel associated with the color well.
    @available(*, deprecated, message: "'colorPanel' is no longer used and will be removed in a future release. Use 'NSColorPanel.shared' instead.")
    public var colorPanel: NSColorPanel { .shared }

    /// A Boolean value indicating whether the color panel associated
    /// with the color well shows alpha values and an opacity slider.
    @available(*, deprecated, message: "Use 'NSColorPanel.shared.showsAlpha' instead.")
    @objc dynamic
    public var showsAlpha: Bool {
        get { NSColorPanel.shared.showsAlpha }
        set { NSColorPanel.shared.showsAlpha = newValue }
    }

    /// Creates a color well with the specified Core Image color.
    ///
    /// - Parameter ciColor: The initial value of the color well's color.
    @available(*, deprecated, renamed: "init(coreImageColor:)", message: "This initializer can result in unexpected runtime behavior. Use the failable 'init(coreImageColor:)' instead.")
    public convenience init(ciColor: CIColor) {
        self.init(color: NSColor(ciColor: ciColor))
    }
}

#if canImport(SwiftUI)
import SwiftUI


// MARK: - PanelColorWellStyle

/// A color well style that displays the color well's color inside of a
/// rectangular control, and toggles the system color panel when clicked.
///
/// You can also use ``colorPanel`` to construct this style.
@available(*, deprecated, renamed: "StandardColorWellStyle", message: "replaced by 'StandardColorWellStyle'")
public struct PanelColorWellStyle: ColorWellStyle {
    public let _configuration = _ColorWellStyleConfiguration(style: .colorPanel)

    /// Creates an instance of the color panel color well style.
    public init() { }
}

@available(*, deprecated, renamed: "StandardColorWellStyle", message: "replaced by 'StandardColorWellStyle'")
extension ColorWellStyle where Self == PanelColorWellStyle {
    /// A color well style that displays the color well's color inside of a
    /// rectangular control, and toggles the system color panel when clicked.
    @available(*, deprecated, renamed: "standard", message: "replaced by 'standard'")
    public static var colorPanel: PanelColorWellStyle {
        PanelColorWellStyle()
    }
}
#endif
