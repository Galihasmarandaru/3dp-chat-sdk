//
//  StringExtensions.swift
//  imi-dolphin-livechat-ios
//

import Foundation

/*
 Extension for parsing filelink which received from chat history
 Response : filename
 */
extension String {
    
    func parsingData() -> String {
        let addQuotes = self.replacingOccurrences(of: "'", with: "\"", options: .literal)
        guard let data = addQuotes.data(using: .utf8) else {
            return self
        }
        
        do {
            if let dictionary = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any],
               let filename = dictionary["filename"] as? String {
                return filename
            }
        } catch {
            // Not a JSON dictionary, fallback gracefully
        }
        return self
    }
}
