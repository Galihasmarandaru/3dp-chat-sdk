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
        
        let data = addQuotes.data(using: String.Encoding.utf8)
        var dictonary: NSDictionary?
        do {
            dictonary = try JSONSerialization.jsonObject(with: data!, options: [.allowFragments]) as? [String: AnyObject] as NSDictionary?
        } catch let error as NSError {
            print(error)
        }
        return dictonary!["filename"]! as! String
    }
}
