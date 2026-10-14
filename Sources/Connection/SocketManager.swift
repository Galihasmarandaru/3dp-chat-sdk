//
//  SocketManager.swift
//  imi-dolphin-livechat-ios
//

import Foundation
import StompClientLib
import UIKit

public class SocketManager: NSObject, StompClientLibDelegate {
    
    public var isConnecting: Bool = false
    public var isConnected: Bool = false
    public var socketClient = StompClientLib()
    public var socketUrl = NSURL()
    public var wsMessage: String?
    public var wsAck: String = ""
    public var sessionId: String?
    
    let topic_ACK: String = "/topic/ack-"
    let topic_messageEndpoint: String = "/topic/message-"
    let destinationUrl = "/app/wmessage"
    
    public override init() {
        super.init()
    }
    
    /*
     Starting connection to web socket
     */
    public func doConnectToStomp(baseUrl: String, accessToken: String, dolphinProfile: DolphinProfile, token: inout String) {
        print("doConnectToWS()")
        var cutHttp: String = ""
        if baseUrl.hasPrefix("http://") {
            let index = baseUrl.index(baseUrl.startIndex, offsetBy: 7)
            cutHttp = String(baseUrl[index...])
        } else {
            let index = baseUrl.index(baseUrl.startIndex, offsetBy: 8)
            cutHttp = String(baseUrl[index...])
        }
        let completedWSURL = "wss://\(cutHttp)/webchat/websocket?access_token=\(accessToken)"
        guard let url = NSURL(string: completedWSURL) else {
            print("Invalid socket URL: \(completedWSURL)")
            return
        }
        socketUrl = url
        
        print("socketUrl", socketUrl)
        token = (dolphinProfile.name ?? "") + (dolphinProfile.email ?? "") + (dolphinProfile.phoneNumber ?? "") + (dolphinProfile.uid ?? "")
        token = AESEncryption.MD5(cipherKey: token)
        
        socketClient.openSocketWithURLRequest(request: NSURLRequest(url: socketUrl as URL), delegate: self, connectionHeaders: [
            "accessToken": accessToken,
            "name": dolphinProfile.name ?? "",
            "email": dolphinProfile.email ?? "",
            "phone": dolphinProfile.phoneNumber ?? "",
            "uid": dolphinProfile.uid ?? ""
        ])
    }
    
    public func doDisconnectToWs() {
        socketClient.disconnect()
    }
    
    public func doReconnectToWs(accessToken: String, dolphinProfile: DolphinProfile?) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(rawValue: notificationConnectionStatus), object: 3)
        }
        socketClient.autoDisconnect(time: 3)
        socketClient.reconnect(request: NSURLRequest(url: socketUrl as URL), delegate: self, connectionHeaders: [
            "accessToken": accessToken,
            "name": dolphinProfile?.name ?? "",
            "email": dolphinProfile?.email ?? "",
            "phone": dolphinProfile?.phoneNumber ?? "",
            "uid": dolphinProfile?.uid ?? ""
        ], time: 4)
    }
    
    public func subscribeMessage(accessToken: String, token: String) {
        wsMessage = topic_messageEndpoint + token
        let id = wsMessage
        let ack = wsMessage
        let headers = ["accessToken": accessToken, "ack": ack!, "id": id!]
        socketClient.subscribeWithHeader(destination: wsMessage!, withHeader: headers)
    }
    
    public func unsubscribeMessage() {
        if let wsMessage = wsMessage {
            print("current ws \(wsMessage)")
            socketClient.unsubscribe(destination: wsMessage)
        }
    }
    
    public func subscribeTransaction(accessToken: String) {
        wsAck = topic_ACK + accessToken
        let id = wsAck
        let headers = ["ack": "client", "id": id, "accessToken": accessToken]
        socketClient.subscribeWithHeader(destination: wsAck, withHeader: headers)
    }
    
    public func onSend(message: DolphinMessage, accessToken: String, clientSecret: String, attachmentManager: AttachmentManager) {
        let msgToSend = DolphinMessage(
            agent: message.agent,
            agentAvatar: message.agentAvatar,
            agentName: message.agentName,
            attFilename: message.attFilename,
            attFilepath: message.attFilepath,
            attFilesize: message.attFilesize,
            attFiletype: message.attFiletype,
            attUrl: message.attUrl,
            customVariables: message.customVariables,
            disconnect: message.disconnect,
            event: message.event,
            inbound: message.inbound,
            iv: message.iv,
            label: message.label,
            language: message.language,
            latitude: message.latitude,
            longitude: message.longitude,
            message: message.message,
            messageHash: message.messageHash,
            outbound: message.outbound,
            salt: message.salt,
            sessionId: message.sessionId,
            token: message.token,
            transactionId: message.transactionId,
            isUser: message.isUser,
            createdDate: message.createdDate,
            state: message.state,
            preCustomVar: message.preCustomVar
        )
        if msgToSend.preCustomVar != nil {
            msgToSend.customVariables = attachmentManager.parsingDataUserInformation(dataUser: msgToSend.preCustomVar!)
        }
        do {
            let txId = msgToSend.transactionId ?? String(Int(NSDate().timeIntervalSince1970))
            let headers = [
                "accessToken": accessToken,
                "transaction": txId,
                "content-type": "application/json"
            ]
            
            AESEncryption.doEncrypt(clientSecret: clientSecret, message: msgToSend, accessToken: accessToken)
             
            let jsonObj = try JSONEncoder().encode(msgToSend)
            let jsonBody = String(data: jsonObj, encoding: .utf8)
            
            socketClient.begin(transactionId: txId)
            socketClient.sendMessage(
                message: jsonBody ?? "",
                toDestination: self.destinationUrl,
                withHeaders: headers,
                withReceipt: nil
            )
            socketClient.commit(transactionId: txId)
        } catch {
            print("Error send message")
        }
    }
    
    public func getChatHistory(baseUrl: String, accessToken: String, dolphinProfile: DolphinProfile?) {
        guard let dolphinProfile = dolphinProfile else { return }
        var socialid: String = (dolphinProfile.phoneNumber ?? "") + "-" + (dolphinProfile.name ?? "")
        if !(dolphinProfile.customerId ?? "").isEmpty {
            socialid = dolphinProfile.customerId!
        }
        guard let url = URL(string: "\(baseUrl)/webchat/conversation?contactid=\(socialid)&access_token=\(accessToken)") else {
            return
        }
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10)
        request.httpMethod = "GET"
        
        let dataTask = URLSession.shared.dataTask(with: request, completionHandler: { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                print(error?.localizedDescription ?? "No Data")
                return
            }
            guard let firstByte = data.first, firstByte == UInt8(ascii: "[") else {
                return
            }
            do {
                var chatHistories = try JSONDecoder().decode([DolphinChatHistory].self, from: data)
                chatHistories.reverse()
                DispatchQueue.main.async {
                    for chatMessage in chatHistories {
                        if let msg = chatMessage.message, !msg.isEmpty {
                            let dolphinMessage = DolphinMessage.parsingHistoryToMessage(chatMessage: chatMessage, state: Constants.message)
                            NotificationCenter.default.post(name: Notification.Name(rawValue: notificationMessage), object: dolphinMessage)
                        } else {
                            let dolphinMessage: DolphinMessage?
                            if let link = chatMessage.documentLink {
                                dolphinMessage = self.parseAttachmentMessage(chatMessage: chatMessage, link: link, type: "document", state: Constants.document, baseUrl: baseUrl, accessToken: accessToken, userName: dolphinProfile.name)
                            } else if let link = chatMessage.videoLink {
                                dolphinMessage = self.parseAttachmentMessage(chatMessage: chatMessage, link: link, type: "video", state: Constants.video, baseUrl: baseUrl, accessToken: accessToken, userName: dolphinProfile.name)
                            } else if let link = chatMessage.audioLink {
                                dolphinMessage = self.parseAttachmentMessage(chatMessage: chatMessage, link: link, type: "audio", state: Constants.audio, baseUrl: baseUrl, accessToken: accessToken, userName: dolphinProfile.name)
                            } else if let link = chatMessage.pictureLink {
                                dolphinMessage = self.parseAttachmentMessage(chatMessage: chatMessage, link: link, type: "image", state: Constants.image, baseUrl: baseUrl, accessToken: accessToken, userName: dolphinProfile.name)
                            } else {
                                dolphinMessage = nil
                            }
                            
                            if let message = dolphinMessage {
                                NotificationCenter.default.post(name: Notification.Name(rawValue: notificationMessage), object: message)
                            }
                        }
                    }
                }
            } catch {
                print("Failed to decode chat histories: \(error)")
            }
        })
        dataTask.resume()
    }
    
    private func parseAttachmentMessage(
        chatMessage: DolphinChatHistory,
        link: String,
        type: String,
        state: String,
        baseUrl: String,
        accessToken: String,
        userName: String?
    ) -> DolphinMessage {
        let filename = link.parsingData()
        let direction = (chatMessage.accountName != userName) ? "out" : "in"
        let attachmentUrl = "\(baseUrl)/webchat/\(direction)/\(type)/\(filename)?access_token=\(accessToken)"
        return DolphinMessage.parsingHistoryToMessage(
            chatMessage: chatMessage,
            filename: filename,
            attachmentUrl: attachmentUrl,
            state: state
        )
    }
    
    public func stompClient(client: StompClientLib!, didReceiveMessageWithJSONBody jsonBody: AnyObject?, akaStringBody stringBody: String?, withHeader header: [String : String]?, withDestination destination: String) {
        print("String Body : \(stringBody ?? "nil")")
        guard let stringBody = stringBody else { return }
        let data = Data(stringBody.utf8)
        if destination.contains("/topic/ack") {
            print("ack response server")
        } else {
            do {
                let onReceivingMessage: DolphinMessage = try JSONDecoder().decode(DolphinMessage.self, from: data)
                let connector = Connector.shared
                let msgDecrypted = AESEncryption.doDecrypt(clientSecret: connector.clientSecrect, accessToken: connector.access_token, messageToDec: onReceivingMessage) ?? onReceivingMessage
                
                if msgDecrypted.message == nil && msgDecrypted.event == nil && msgDecrypted.token != nil {
                    connector.token = msgDecrypted.token!
                    if msgDecrypted.sessionId != nil {
                        self.sessionId = msgDecrypted.sessionId
                        connector.sessionId = msgDecrypted.sessionId
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: Notification.Name(rawValue: notificationConnectionStatus), object: 2)
                        }
                    }
                    subscribeTransaction(accessToken: connector.access_token)
                } else {
                    setEvent(msgDecriypted: msgDecrypted)
                }

            } catch let error as NSError {
                print("Failed to load: \(error.localizedDescription)")
            }
        }
    }
    
    public func setEvent(msgDecriypted: DolphinMessage) {
        if msgDecriypted.event == "diconnect" || msgDecriypted.event == "disconnect" {
            print("User is disconnected")
        } else if msgDecriypted.event == "read" {
            print("read")
            NotificationCenter.default.post(name: Notification.Name(rawValue: notificationReadMessage), object: msgDecriypted)
        } else if msgDecriypted.event == "typing" {
            print("typing")
            NotificationCenter.default.post(name: Notification.Name(rawValue: notificationTypingCondition), object: msgDecriypted)
        } else {
            incomingMessage(incomingMsg: msgDecriypted)
        }
    }
    
    public func incomingMessage(incomingMsg: DolphinMessage) {
        incomingMsg.isUser = false
        if incomingMsg.message != nil {
            NotificationCenter.default.post(name: Notification.Name(rawValue: notificationMessage), object: incomingMsg)
        } else if let rawAttUrl = incomingMsg.attUrl {
            let connector = Connector.shared
            incomingMsg.attUrl = connector.getUrlFile(url: rawAttUrl)
            let fileType = incomingMsg.attFiletype ?? ""
            if fileType.contains(Constants.image) {
                connector.setIncomingFileTypeAndState(message: incomingMsg, state: Constants.image)
            } else if fileType.contains(Constants.video) || fileType.contains(Connector.CONSTANT_TYPE_OCTET_STREAM) {
                connector.setIncomingFileTypeAndState(message: incomingMsg, state: Constants.video)
            } else if fileType.contains(Connector.CONSTANT_TYPE_DOCUMENT) || fileType.contains(Connector.CONSTANT_TYPE_APPLICATION) {
                connector.setIncomingFileTypeAndState(message: incomingMsg, state: Constants.document)
            } else if fileType.contains(Connector.CONSTANT_TYPE_AUDIO) {
                connector.setIncomingFileTypeAndState(message: incomingMsg, state: Constants.audio)
            }
            NotificationCenter.default.post(name: Notification.Name(rawValue: notificationMessage), object: incomingMsg)
        }
    }
    
    public func serverDidSendReceipt(client: StompClientLib!, withReceiptId receiptId: String) {
        print("Receipt : \(receiptId)")
    }
    
    public func stompClientDidDisconnect(client: StompClientLib!) {
        print("stompClientDidDisconnect")
        isConnecting = false
        isConnected = false
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(rawValue: notificationConnectionStatus), object: 4)
        }
    }
    
    public func stompClientDidConnect(client: StompClientLib!) {
        let connector = Connector.shared
        subscribeMessage(accessToken: connector.access_token, token: connector.token)
        isConnecting = false
        isConnected = true
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(rawValue: notificationConnectionStatus), object: 2)
        }
        
        connector.onSendMessage(messages: "Halo")
        
        if connector.isEnableQueue {
            getChatHistory(baseUrl: connector.baseUrl, accessToken: connector.access_token, dolphinProfile: connector.dolphinProfile)
        }
    }

    
    public func serverDidSendError(client: StompClientLib!, withErrorMessage description: String, detailedErrorMessage message: String?) {
        print("serverDidSendError: \(description)")
        NotificationCenter.default.post(name: Notification.Name(rawValue: notificationConnectionStatus), object: 5)
    }
    
    public func serverDidSendPing() {
        print("server ping")
    }
}
