//
//  AnySpecification.swift
//  SpecificationCore
//
//  Created by SpecificationCore on 2025.
//

import Foundation

/// A type-erased wrapper for any specification optimized for performance.
/// This allows you to store specifications of different concrete types in the same collection
/// or use them in contexts where the specific type isn't known at compile time.
///
/// ## Performance Optimizations
///
/// - **@inlinable methods**: Enable compiler optimization across module boundaries
/// - **Specialized storage**: Different storage strategies based on specification type
/// - **Copy-on-write semantics**: Minimize memory allocations
/// - **Thread-safe design**: No internal state requiring synchronization
public struct AnySpecification<T>: Specification {
    // MARK: - Optimized Storage Strategy

    /// Internal storage that uses different strategies based on the specification type
    @usableFromInline
    enum Storage {
        case predicate((T) -> Bool)
        #if Tracing
            case specification(any Specification<T>, String)
        #else
            case specification(any Specification<T>)
        #endif
        case constantTrue
        case constantFalse
    }

    @usableFromInline
    let storage: Storage

    // MARK: - Initializers

    /// Creates a type-erased specification wrapping the given specification.
    /// - Parameter specification: The specification to wrap
    @inlinable
    public init<S: Specification>(_ specification: S) where S.T == T {
        // Optimize for common patterns
        if specification is AlwaysTrueSpec<T> {
            storage = .constantTrue
        } else if specification is AlwaysFalseSpec<T> {
            storage = .constantFalse
        } else {
            // Store the specification directly for better performance
            #if Tracing
                storage = .specification(specification, String(reflecting: S.self))
            #else
                storage = .specification(specification)
            #endif
        }
    }

    /// Creates a type-erased specification from a closure.
    /// - Parameter predicate: A closure that takes a candidate and returns whether it satisfies the specification
    @inlinable
    public init(_ predicate: @escaping (T) -> Bool) {
        storage = .predicate(predicate)
    }

    // MARK: - Core Specification Protocol

    @inlinable
    public func isSatisfiedBy(_ candidate: T) -> Bool {
        switch storage {
        case .constantTrue:
            #if Tracing
                return SpecificationTraceRuntime.withBoolean("AlwaysTrueSpec") { true }
            #else
                return true
            #endif
        case .constantFalse:
            #if Tracing
                return SpecificationTraceRuntime.withBoolean("AlwaysFalseSpec") { false }
            #else
                return false
            #endif
        case let .predicate(predicate):
            #if Tracing
                return SpecificationTraceRuntime.withBoolean("predicate") { predicate(candidate) }
            #else
                return predicate(candidate)
            #endif
        #if Tracing
            case let .specification(spec, name):
                return SpecificationTraceRuntime.evaluateChild(spec, candidate, name: name)
        #else
            case let .specification(spec):
                return spec.isSatisfiedBy(candidate)
        #endif
        }
    }
}

#if Tracing
    extension AnySpecification: SpecificationTraceExclusion {
        var excludesSpecificationTracing: Bool {
            if case let .specification(spec, _) = storage {
                return SpecificationTraceRuntime.isExcluded(spec)
            }
            return false
        }
    }
#endif

// MARK: - Convenience Extensions

public extension AnySpecification {
    /// Creates a specification that always returns true
    @inlinable
    static var always: AnySpecification<T> {
        AnySpecification { _ in true }
    }

    /// Creates a specification that always returns false
    @inlinable
    static var never: AnySpecification<T> {
        AnySpecification { _ in false }
    }

    /// Creates an optimized constant true specification
    @inlinable
    static func constantTrue() -> AnySpecification<T> {
        AnySpecification(AlwaysTrueSpec<T>())
    }

    /// Creates an optimized constant false specification
    @inlinable
    static func constantFalse() -> AnySpecification<T> {
        AnySpecification(AlwaysFalseSpec<T>())
    }
}

// MARK: - Collection Extensions

public extension Collection where Element: Specification {
    /// Creates a specification that is satisfied when all specifications in the collection are satisfied
    /// - Returns: An AnySpecification that represents the AND of all specifications
    @inlinable
    func allSatisfied() -> AnySpecification<Element.T> {
        let elementCount = count
        // Optimize for empty collection
        guard elementCount > 0 else { return .constantTrue() }

        // Optimize for single element
        if elementCount == 1, let first {
            return AnySpecification(first)
        }

        return AnySpecification { candidate in
            #if Tracing
                var currentIndex = startIndex
                var visitedCount = 0
                while currentIndex != endIndex {
                    let specification = self[currentIndex]
                    visitedCount += 1
                    guard SpecificationTraceRuntime.evaluateChild(
                        specification, candidate, name: String(reflecting: Element.self)
                    ) else {
                        if SpecificationTraceRuntime.isRecording {
                            for _ in visitedCount ..< elementCount {
                                SpecificationTraceRuntime.skip(String(reflecting: Element.self))
                            }
                        }
                        return false
                    }
                    formIndex(after: &currentIndex)
                }
                return true
            #else
                self.allSatisfy { spec in
                    spec.isSatisfiedBy(candidate)
                }
            #endif
        }
    }

    /// Creates a specification that is satisfied when any specification in the collection is satisfied
    /// - Returns: An AnySpecification that represents the OR of all specifications
    @inlinable
    func anySatisfied() -> AnySpecification<Element.T> {
        let elementCount = count
        // Optimize for empty collection
        guard elementCount > 0 else { return .constantFalse() }

        // Optimize for single element
        if elementCount == 1, let first {
            return AnySpecification(first)
        }

        return AnySpecification { candidate in
            #if Tracing
                var currentIndex = startIndex
                var visitedCount = 0
                while currentIndex != endIndex {
                    let specification = self[currentIndex]
                    visitedCount += 1
                    if SpecificationTraceRuntime.evaluateChild(
                        specification, candidate, name: String(reflecting: Element.self)
                    ) {
                        if SpecificationTraceRuntime.isRecording {
                            for _ in visitedCount ..< elementCount {
                                SpecificationTraceRuntime.skip(String(reflecting: Element.self))
                            }
                        }
                        return true
                    }
                    formIndex(after: &currentIndex)
                }
                return false
            #else
                self.contains { spec in
                    spec.isSatisfiedBy(candidate)
                }
            #endif
        }
    }
}

// MARK: - Helper Specs for AnySpecification

/// A specification that always evaluates to true
public struct AlwaysTrueSpec<T>: Specification {
    /// Creates a new AlwaysTrueSpec
    public init() {}

    public func isSatisfiedBy(_ candidate: T) -> Bool {
        true
    }
}

/// A specification that always evaluates to false
public struct AlwaysFalseSpec<T>: Specification {
    /// Creates a new AlwaysFalseSpec
    public init() {}

    public func isSatisfiedBy(_ candidate: T) -> Bool {
        false
    }
}
