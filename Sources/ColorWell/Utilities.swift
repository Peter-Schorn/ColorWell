//===----------------------------------------------------------------------===//
//
// Utilities.swift
//
//===----------------------------------------------------------------------===//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Counter

/// A counter type that must be incremented in order for its value to be
/// accessed, ensuring an accurate count.
internal struct Counter {
    /// A pointer containing the counter's value.
    ///
    /// We use a pointer, rather than an integer to avoid having to declare
    /// counters as `var`.
    private let pointer: UnsafeMutablePointer<Int> = {
        let pointer = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        pointer.pointee = 0
        return pointer
    }()

    /// Creates a counter initialized to `0`.
    init() { }

    /// Returns the current value and increments the counter.
    func bump() -> Int {
        defer {
            pointer.pointee += 1
        }
        return pointer.pointee
    }
}

// MARK: - ComparableID

/// An identifier type that can be compared by order of creation.
///
/// For identifiers `id1` and `id2`, `id1 < id2` if `id1` was created first.
internal struct ComparableID {
    private static let counter = Counter()

    private let root = UUID()
    private let count = counter.bump()

    /// Creates a unique identifier that can be compared with other
    /// instances of this type according to the order in which they
    /// were created.
    init() { }
}

// MARK: ComparableID: Comparable
extension ComparableID: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.count < rhs.count
    }
}

// MARK: ComparableID: Equatable
extension ComparableID: Equatable { }

// MARK: ComparableID: Hashable
extension ComparableID: Hashable { }

// MARK: - ChangeHandler

/// An identifiable, hashable wrapper for a change handler
/// that is executed when a color well's color changes.
///
/// This type can be compared by order of creation.
///
/// For handlers `h1` and `h2`, `h1 < h2` if `h1` was created first.
internal struct ChangeHandler {
    private let id: ComparableID
    private let handler: (NSColor) -> Void

    /// Creates a change handler with the given identifier and closure.
    ///
    /// - Parameters:
    ///   - id: An identifier that can be compared by order of creation.
    ///   - handler: A closure to store for later execution.
    init(id: ComparableID, handler: @escaping (NSColor) -> Void) {
        self.id = id
        self.handler = handler
    }

    /// Creates a change handler from a closure.
    ///
    /// This initializer automatically creates the handler's identifier.
    ///
    /// - Parameter handler: A closure to store for later execution.
    init(handler: @escaping (NSColor) -> Void) {
        self.init(id: .init(), handler: handler)
    }

    /// Invokes the closure that is stored by this instance, passing the
    /// given color as an argument.
    ///
    /// - Parameter color: The color to pass into the handler's closure.
    func callAsFunction(_ color: NSColor) {
        handler(color)
    }
}

// MARK: ChangeHandler: Comparable
extension ChangeHandler: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.id < rhs.id
    }
}

// MARK: ChangeHandler: Equatable
extension ChangeHandler: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: ChangeHandler: Hashable
extension ChangeHandler: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Storage

/// A type that uses object association to store external values.
internal class Storage<Value> {
    private let policy: AssociationPolicy

    private var key: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(self).toOpaque()
    }

    /// Creates a storage object that stores values of the
    /// given type, using the provided association policy.
    init(
        _ type: Value.Type = Value.self,
        policy: @autoclosure () -> AssociationPolicy = .retain(false)
    ) {
        self.policy = policy()
    }

    /// Accesses the value for the given object.
    subscript<Object: AnyObject>(_ object: Object) -> Value? {
        get { objc_getAssociatedObject(object, key) as? Value }
        set { objc_setAssociatedObject(object, key, newValue, policy.objcValue) }
    }
}

// MARK: - AssociationPolicy

/// A type that specifies the behavior of an object association.
internal struct AssociationPolicy {
    fileprivate let objcValue: objc_AssociationPolicy

    private init(_ objcValue: objc_AssociationPolicy) {
        self.objcValue = objcValue
    }
}

// MARK: AssociationPolicy Static Members
extension AssociationPolicy {
    /// A weak reference to the associated object.
    static var assign: Self {
        .init(.OBJC_ASSOCIATION_ASSIGN)
    }

    /// The associated object is copied.
    static func copy(_ isAtomic: Bool) -> Self {
        guard isAtomic else {
            return .init(.OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
        return .init(.OBJC_ASSOCIATION_COPY)
    }

    /// A strong reference to the associated object.
    static func retain(_ isAtomic: Bool) -> Self {
        guard isAtomic else {
            return .init(.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return .init(.OBJC_ASSOCIATION_RETAIN)
    }
}

// MARK: - SwiftUI Utilities

#if canImport(SwiftUI)

// MARK: - ViewConstructor

@available(macOS 10.15, *)
internal struct ViewConstructor<Content: View>: View {
    private let content: Content

    var body: some View {
        content
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    init(content: @autoclosure () -> Content) {
        self.init(content: content)
    }

    func with<Modified: View>(@ViewBuilder _ block: (Content) -> Modified) -> ViewConstructor<Modified> {
        .init(content: block(content))
    }

    func erased() -> AnyViewConstructor {
        .init(base: self)
    }
}

// MARK: - AnyViewConstructor

@available(macOS 10.15, *)
internal struct AnyViewConstructor: View {
    let base: any View

    var body: some View {
        AnyView(base)
    }

    init<Content: View>(base: ViewConstructor<Content>) {
        self.base = base
    }

    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.init(base: .init(content: content))
    }

    init<Content: View>(content: @autoclosure () -> Content) {
        self.init(content: content)
    }
}

// MARK: - CustomCocoaConvertible

internal protocol CustomCocoaConvertible<CocoaType, Converted> {
    associatedtype CocoaType: NSObject
    associatedtype Converted: CustomCocoaConvertible = Self
    static func converted(from source: CocoaType) -> Converted
}

// MARK: Color: CustomCocoaConvertible
@available(macOS 10.15, *)
extension Color: CustomCocoaConvertible {
    internal static func converted(from source: NSColor) -> Self {
        .init(source)
    }
}

// MARK: CGColor: CustomCocoaConvertible
extension CGColor: CustomCocoaConvertible {
    internal static func converted(from source: NSColor) -> CGColor {
        source.cgColor
    }
}

// MARK: - StringProtocol Label

@available(macOS 10.15, *)
extension StringProtocol {
    internal var label: Text { .init(self) }
}
#endif

// MARK: - ReferencePath

/// A type that references a value using an object and a keypath.
internal struct ReferencePath<Root, Value> {
    private let root: Root
    private let keyPath: ReferenceWritableKeyPath<Root, Value>

    /// Provides direct access to the value referenced by this path.
    var value: Value {
        get {
            root[keyPath: keyPath]
        }
        nonmutating set {
            root[keyPath: keyPath] = newValue
        }
    }

    /// Creates a reference path using the given object and keypath.
    init(_ root: Root, keyPath: ReferenceWritableKeyPath<Root, Value>) {
        self.root = root
        self.keyPath = keyPath
    }

    /// Creates a reference path using the object and keypath in the
    /// given tuple.
    init(_ tuple: (Root, ReferenceWritableKeyPath<Root, Value>)) {
        self.init(tuple.0, keyPath: tuple.1)
    }
}

// MARK: - With Temporary Change

/// Evaluates a closure after temporarily changing the specified value to
/// a given secondary value, restoring the original value after the block
/// returns.
///
/// - Parameters:
///   - path: A value containing an object and a keypath to one of its
///     properties.
///   - tempValue: The secondary value to change the value at `path`'s
///     keypath to.
///   - body: A closure to perform after `tempValue` has replaced the
///     keypath's value.
///
/// - Returns: Whatever is returned by `body`.
internal func withTemporaryChange<T, U, V>(
    of path: ReferencePath<T, U>,
    to tempValue: @autoclosure () throws -> U,
    _ body: () throws -> V
) rethrows -> V {
    let cached = path.value
    path.value = try tempValue()
    defer {
        path.value = cached
    }
    return try body()
}

/// Evaluates a closure after temporarily changing the specified value to
/// a given secondary value, restoring the original value after the block
/// returns.
///
/// - Parameters:
///   - path: A tuple containing an object and a keypath to one of its
///     properties.
///   - tempValue: The secondary value to change the value at `path`'s
///     keypath to.
///   - body: A closure to perform after `tempValue` has replaced the
///     keypath's value.
///
/// - Returns: Whatever is returned by `body`.
internal func withTemporaryChange<T, U, V>(
    of path: (T, ReferenceWritableKeyPath<T, U>),
    to tempValue: @autoclosure () throws -> U,
    _ body: () throws -> V
) rethrows -> V {
    try withTemporaryChange(
        of: ReferencePath(path),
        to: tempValue(),
        body
    )
}
