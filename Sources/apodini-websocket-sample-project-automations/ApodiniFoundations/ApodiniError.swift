//
//  File.swift
//  
//
//  Created by Max Obermeier on 02.02.21.
//

import Foundation
import Apodini

extension ApodiniError {
    func callAsFunction(_ error: LocalizedError) -> ApodiniError {
        self(reason: error.failureReason, description: error.errorDescription ?? error.recoverySuggestion ?? error.helpAnchor ?? error.localizedDescription)
    }
}

extension ApodiniError {
    func rethrow<T>(_ action: @autoclosure () throws -> T) throws -> T {
        do {
            return try action()
        } catch {
            if let localized = error as? LocalizedError {
                throw self(localized)
            } else {
                throw self(description: error.localizedDescription)
            }
        }
    }
}
