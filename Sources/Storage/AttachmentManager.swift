//
//  AttachmentManager.swift
//  imi-dolphin-livechat-ios
//

import Foundation

public class AttachmentManager {
    
    public init() {}
    
    /*
     Send attachment (file, image, video, and audio) to server
     */
    public func sendAttachment(baseUrl: String, accessToken: String, clientSecret: String, sessionId: String?, dolphinProfile: DolphinProfile?, token: String, fileNsUrl: NSURL?, state: String, dataUser: AnyObject? = nil, onSend: @escaping (DolphinMessage) -> Void) {
        
        var jsonString: Data?
        
        if dataUser != nil {
            jsonString = convertDataToJson(data: dataUser as Any)
        }
        
        guard let fileNsUrl = fileNsUrl, let url = URL(string: "\(baseUrl)/webchat/upload") else {
            return
        }
        
        let mediaImage: DolphinMessage = preRenderFileMessage(token: token, sessionId: sessionId, dolphinProfile: dolphinProfile, fileNsUrl: fileNsUrl, state: state)
        let boundary = "--------------\(UUID().uuidString)"
        let session = URLSession.shared
        let mimeType = getMimeByState(state: state)
        let fileData = convertToDataByMime(fileNsUrl: fileNsUrl, mimeType: mimeType)
        let fileName = fileNsUrl.lastPathComponent ?? "file"
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        var body = Data()
        if let partHeader = "\r\n--\(boundary)\r\ncontent-disposition: form-data; name=\"attachment\"; filename=\"\(fileName)\"\r\nContent-Type: \(mimeType)\r\n\r\n".data(using: .utf8) {
            body.append(partHeader)
        }
        body.append(fileData)
    
        if let sid = sessionId, !sid.isEmpty {
            if let sidPart = "\r\n--\(boundary)\r\ncontent-disposition: form-data; name=\"sessionId\"\r\n\r\n\(sid)\r\n".data(using: .utf8) {
                body.append(sidPart)
            }
        }
        if let closingBoundary = "--\(boundary)--\r\n".data(using: .utf8) {
            body.append(closingBoundary)
        }
        
        session.uploadTask(with: urlRequest, from: body, completionHandler: { [weak self] responseData, response, error in
            guard let self = self else { return }
            if let error = error {
                print("Attachment upload error:", error)
            }
            if let response = response as? HTTPURLResponse {
                print("statusCode: \(response.statusCode)")
            }
            guard let responseData = responseData else {
                print("no response data")
                return
            }
            if let responseString = String(data: responseData, encoding: .utf8) {
                if responseString.contains("You can not upload") {
                    print("Upload forbidden by server")
                } else if let decodedData = Data(base64Encoded: responseString) {
                    do {
                        if let jsonObject = try JSONSerialization.jsonObject(with: decodedData, options: .allowFragments) as? [String: Any] {
                            if let message = jsonObject["message"] as? String, message == "Filesize limit exceeded" {
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(name: Notification.Name(rawValue: notificationConnectionStatus), object: 6)
                                }
                            } else {
                                mediaImage.attFilepath = jsonObject["filepath"] as? String
                                mediaImage.attFilename = jsonObject["filename"] as? String
                                mediaImage.attFiletype = jsonObject["filetype"] as? String
                                mediaImage.attUrl = self.getAttachmentURL(baseUrl: baseUrl, json: jsonObject as NSDictionary)
                                mediaImage.preCustomVar = jsonString
                                onSend(mediaImage)
                            }
                        }
                    } catch let parsingError {
                        print("Error parsing upload response:", parsingError)
                    }
                }
            }
        }).resume()
    }
    
    // MARK: - File Upload Image, Word, Excel, PDF
    public func validateFileMimeType(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let validExtensions = ["png", "jpg", "jpeg", "pdf", "doc", "docx", "xls", "xlsx"]
        return validExtensions.contains(ext)
    }
    
    public func getMimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "pdf":
            return "application/pdf"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":
            return "application/vnd.ms-excel"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        default:
            return "application/octet-stream"
        }
    }
    
    public func getMimeByState(state: String) -> String {
        if state == Constants.image {
            return Constants.image
        } else if state == Constants.document {
            return Constants.document
        } else if state == Constants.audio {
            return Constants.audio
        } else {
            return Constants.video
        }
    }

    
    public func convertToDataByMime(fileNsUrl: NSURL, mimeType: String) -> Data {
        var resData = Data()
        do {
            resData = try Data(contentsOf: fileNsUrl as URL)
        } catch {
            print("Error converting file data")
        }
        return resData
    }
    
    public func getAttachmentURL(baseUrl: String, json: NSDictionary) -> String {
        var type: String = json["filetype"] as! String
        var filename: String = json["filename"] as! String
        
        if type.starts(with: Connector.CONSTANT_TYPE_IMAGE) {
            type = Constants.image
        } else if type.starts(with: Connector.CONSTANT_TYPE_DOCUMENT) {
            type = Constants.document
        } else if type.starts(with: Connector.CONSTANT_TYPE_AUDIO) {
            type = Constants.audio
        } else if type.starts(with: Connector.CONSTANT_TYPE_VIDEO) {
            type = Constants.video
        }
        
        filename = filename.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        
        print("URL: \(baseUrl)/webchat/in/\(type)/\(filename)")
        return "\(baseUrl)/webchat/in/\(type)/\(filename)"
    }
    
    public func preRenderFileMessage(token: String, sessionId: String?, dolphinProfile: DolphinProfile?, fileNsUrl: NSURL, state: String) -> DolphinMessage {
        let mediaMessage: DolphinMessage = DolphinMessage()
        
        mediaMessage.attUrl = fileNsUrl.absoluteString
        mediaMessage.token = token
        mediaMessage.outbound = false
        mediaMessage.isUser = true
        let transactionId: String = String(Int(NSDate().timeIntervalSince1970))
        mediaMessage.transactionId = transactionId
        mediaMessage.sessionId = sessionId
        mediaMessage.agentName = dolphinProfile?.name ?? ""
        mediaMessage.attFiletype = state
        
        setIncomingFileTypeAndState(message: mediaMessage, state: state)
        NotificationCenter.default.post(name: Notification.Name(rawValue: notificationMessage), object: mediaMessage)
        return mediaMessage
    }
    
    public func setIncomingFileTypeAndState(message: DolphinMessage, state: String) {
        message.attFiletype = state
        message.state = state
    }
    
    public func convertDataToJson(data: Any) -> Data? {
        do {
            return try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    public func parsingDataUserInformation(dataUser: Data) -> String? {
        var result: String?
        do {
            let decoded = try JSONSerialization.jsonObject(with: dataUser, options: [])
            if let decodedFromJson = decoded as? [String: String] {
                let dataMapUser = [
                    ["gpsLocation": decodedFromJson["gpsLocation"]],
                    ["networkName": decodedFromJson["networkName"]],
                    ["networkMode": decodedFromJson["networkMode"]],
                    ["signalStrength": decodedFromJson["signalStrength"]],
                    ["ipAddress": decodedFromJson["ipAddress"]],
                    ["apn": decodedFromJson["apn"]],
                    ["os": decodedFromJson["os"]],
                    ["noAxis": decodedFromJson["noAxis"]],
                    ["email": decodedFromJson["email"]],
                    ["category": decodedFromJson["category"]],
                    ["imsi": decodedFromJson["imsi"]],
                    ["mcc": decodedFromJson["mcc"]],
                    ["mnc": decodedFromJson["mnc"]],
                    ["lac": decodedFromJson["lac"]],
                    ["cellId": decodedFromJson["cellId"]],
                    ["deviceInfo": decodedFromJson["deviceInfo"]]
                ]
                result = convertDataToJsonString(arrayData: dataMapUser)
            }
        } catch {
            print(error.localizedDescription)
        }
        return result
    }
    
    public func convertDataToJsonString(arrayData: Any) -> String {
        var json: String = ""
        do {
            let jsonData: Data = try JSONSerialization.data(withJSONObject: arrayData, options: [])
            if let jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue) {
                json = jsonString as String
                print(json)
            }
        } catch let error as NSError {
            print("Array convertIntoJSON - \(error.description)")
        }
        return json
    }
}
