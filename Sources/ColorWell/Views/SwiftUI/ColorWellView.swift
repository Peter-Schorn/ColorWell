//
// ColorWellView.swift
// ColorWell
//

#if canImport(SwiftUI)
import SwiftUI

/// A SwiftUI view that displays a user-selectable color value.
///
/// Color wells provide a means for choosing custom colors directly within
/// your app's user interface. A color well displays the currently selected
/// color, and provides options for selecting new colors. There are a number
/// of styles to choose from, each of which provides a different appearance
/// and set of behaviors.
@available(macOS 11, *)
public struct ColorWellView<Label: View>: View {

    @Binding var color: Color
    @Binding var supportsOpacity: Bool
    
    let label: Label?

    public init(
        color: Binding<Color>,
        label: Label?,
        supportsOpacity: Binding<Bool> = .constant(true)
    ) {
        self._color = color
        self._supportsOpacity = supportsOpacity
        self.label = label
    }

    /// The content view of the color well.
    public var body: some View {
        if let label {
            HStack(alignment: .center) {
                label
                representableView
            }
        } else {
            representableView
        }
    }

    
    var representableView: some View {
        ColorWellRepresentable(color: $color, supportsOpacity: $supportsOpacity)
                .fixedSize()
    }

}

@available(macOS 11, *)
public extension ColorWellView where Label == Text {
    
    init<S: StringProtocol>(
        _ title: S,
        color: Binding<Color>,
        supportsOpacity: Binding<Bool> = .constant(true)
    ) {
        self.label = Text(title)
        self._color = color
        self._supportsOpacity = supportsOpacity
    }
    
    init(
        _ titleKey: LocalizedStringKey,
        color: Binding<Color>,
        supportsOpacity: Binding<Bool> = .constant(true)
    ) {
        self.label = Text(titleKey)
        self._color = color
        self._supportsOpacity = supportsOpacity
    }
    
}

@available(macOS 11, *)
public extension ColorWellView where Label == EmptyView {
    
    init(
        color: Binding<Color>,
        supportsOpacity: Binding<Bool> = .constant(true)
    ) {
        self.label = nil
        self._color = color
        self._supportsOpacity = supportsOpacity
    }
    
}

#endif
