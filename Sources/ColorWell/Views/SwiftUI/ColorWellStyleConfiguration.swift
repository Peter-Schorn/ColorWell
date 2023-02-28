//
// ColorWellStyleConfiguration.swift
// ColorWell
//

#if canImport(SwiftUI)
/// Values that configure a color well's style.
public struct ColorWellStyleConfiguration {
    /// The underlying style of the color well.
    internal var style: ColorWell.Style?

    /// Creates a style configuration.
    public init() { }

    /// Creates a style configuration for the specified underlying style.
    internal init(style: ColorWell.Style) {
        self.style = style
    }
}
#endif