//
//  Initial.swift
//  
//
//  Created by Max Obermeier on 04.02.21.
//

import Foundation
import Apodini

@propertyWrapper
struct Initial: DynamicProperty {
    
    @State var _initial: Bool = true
    
    var wrappedValue: Bool {
        get {
            defer { _initial = false }
            return _initial
        }
    }
}
