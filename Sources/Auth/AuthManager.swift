//
//  AuthManager.swift
//  imi-dolphin-livechat-ios
//

import Foundation

public class AuthManager {
    
    public var access_token: String = ""
    public var refresh_token: String = ""
    public var token: String = ""
    
    public init() {}
    
    /*
     Get user access and refresh token
     Result : access_token, refresh_token
     */
    public func getUserToken(baseUrl: String, clientId: String, clientSecret: String, completion: @escaping (_ success: Bool) -> Void) {
        token = "\(clientId):\(clientSecret)".data(using: .utf8)?.base64EncodedString() ?? ""
        let url = URL(string: baseUrl + "/oauth/token?grant_type=password&username=\(clientId)&password=\(clientSecret)")!
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        
        let dataTask = URLSession.shared.dataTask(with: request, completionHandler: { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                print("Auth error: \(error?.localizedDescription ?? "No Data")")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Auth failed with HTTP status: \(httpResponse.statusCode)")
                completion(false)
                return
            }
            
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary
            guard let accessToken = responseJSON?["access_token"] as? String, !accessToken.isEmpty else {
                print("Auth failed: No access_token found in response")
                completion(false)
                return
            }
            
            self.access_token = accessToken
            if let refreshToken = responseJSON?["refresh_token"] as? String {
                self.refresh_token = refreshToken
                self.refreshAccessToken(baseUrl: baseUrl, completion: completion)
            } else {
                completion(true)
            }
        })
        dataTask.resume()
    }
    
    /*
     Refresh token after getUserToken is called
     Result : access_token, refresh_token
     */
    public func refreshAccessToken(baseUrl: String, completion: @escaping (_ success: Bool) -> Void) {
        let url = URL(string: baseUrl + "/oauth/token?grant_type=refresh_token&refresh_token=\(refresh_token)")!
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Basic \(token)", forHTTPHeaderField: "Authorization")
    
        let dataTask = URLSession.shared.dataTask(with: request, completionHandler: { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                print(error?.localizedDescription ?? "No Data")
                completion(false)
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary
            if let accessToken = responseJSON?["access_token"] as? String {
                self.access_token = accessToken
                print("getUserToken() accessToken: " + self.access_token)
            }
            if let refreshToken = responseJSON?["refresh_token"] as? String {
                self.refresh_token = refreshToken
                print("getUserToken() refreshAccessToken: " + self.refresh_token)
            }
            completion(true)
        })
        dataTask.resume()
    }
}

