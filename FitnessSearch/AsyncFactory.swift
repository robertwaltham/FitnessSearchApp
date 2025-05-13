//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2024 Apple Inc. All Rights Reserved.


// adapted from https://github.com/apple/ml-mobileclip/blob/main/ios_app/MobileCLIPExplore/AsyncFactory.swift
import Foundation
import SwiftUI

/// Asynchronous factory for slow-to-load types.
public actor AsyncFactory<T:Sendable> {

    private enum State {
        case idle(@Sendable () -> T)
        case initializing(Task<T, Never>)
        case initialized(T)
    }

    private var state: State
    private let stateBinding: Binding<Bool>?
    
    public func initalized() -> Bool {
        switch state { 
        case .idle(_):
            return false
        case .initializing(_):
            return false
        case .initialized(_):
            return true
        }
    }

    public init(binding: Binding<Bool>? = nil, factory: @escaping @Sendable () -> T) {
        self.state = .idle(factory)
        self.stateBinding = binding
    }

    public func get() async -> T {
        switch state {
        case .idle(let factory):
            let task = Task {
                factory()
            }
            print("Initializing \(T.self)")
            let clock = ContinuousClock()
            let start = clock.now
            self.state = .initializing(task)
            let value = await task.value
            self.state = .initialized(value)
            self.stateBinding?.wrappedValue = true
            let duration = clock.now - start
            print("Loaded \(T.self) (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
            return value

        case .initializing(let task):
            return await task.value

        case .initialized(let v):
            return v
        }
    }
}
