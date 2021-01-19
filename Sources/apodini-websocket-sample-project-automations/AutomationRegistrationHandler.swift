//
//  AutomationRegistrationHandler.swift
//  
//
//  Created by Max Obermeier on 19.01.21.
//

import Apodini

extension Automation: Codable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let description = try container.decode(String.self)
        
        guard let initialized = Self(description) else {
            throw AutomationDecodingError.unableToDecode(description)
        }
                
        self = initialized
    }
}


struct AutomationRegistrationHandler: Handler {
        
    @Parameter var automation: Automation
    
    func handle() throws -> Bool {
        print(automation.description)
        return true
    }
}
