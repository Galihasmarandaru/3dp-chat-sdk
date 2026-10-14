//
//  Connector.swift
//  imi-dolphin-livechat-ios
//
//  Created by Jhoan River S on 04/05/21.
//  Refactored to SRP Modular Architecture.
//

import Foundation
import StompClientLib
import UIKit

public class Connector: StompClientLibDelegate {
    
    
    public var baseUrl: String = ""
    public var clientId: String = ""
    public var clientSecrect: String = ""
    public var isEnableQueue: Bool = false
    public var generativeBaseUrl: String = "https://apollo.3dolphins.ai:9443"
    public var botId: String = "9a85edecbc9393858367a0f918e7022f"
    public var jwtToken: String? = nil
    public var channelId: String = "EMULATOR"
    public var currentConversationId: String = UUID().uuidString
    
    public var graphAuthUrl: String = "https://apollo.3dolphins.ai:9443/dolphin/apiv1/graph/auth"
    public var graphUsername: String = "admin@inmotion.co.id"
    public var graphPassword: String = "admin@Dolphin123"
    
    public let authManager = AuthManager()
    public let socketManager = SocketManager()
    public let attachmentManager = AttachmentManager()
    
    public var access_token: String {
        get { return authManager.access_token }
        set { authManager.access_token = newValue }
    }
    public var refresh_token: String {
        get { return authManager.refresh_token }
        set { authManager.refresh_token = newValue }
    }
    var token: String {
        get { return authManager.token }
        set { authManager.token = newValue }
    }
    
    public var isConnecting: Bool {
        get { return socketManager.isConnecting }
        set { socketManager.isConnecting = newValue }
    }
    public var isConnected: Bool {
        get { return socketManager.isConnected }
        set { socketManager.isConnected = newValue }
    }
    var socketClient: StompClientLib {
        get { return socketManager.socketClient }
        set { socketManager.socketClient = newValue }
    }
    var socketUrl: NSURL {
        get { return socketManager.socketUrl }
        set { socketManager.socketUrl = newValue }
    }
    var wsMessage: String? {
        get { return socketManager.wsMessage }
        set { socketManager.wsMessage = newValue }
    }
    var wsAck: String {
        get { return socketManager.wsAck }
        set { socketManager.wsAck = newValue }
    }
    public var sessionId: String? {
        get { return socketManager.sessionId }
        set { socketManager.sessionId = newValue }
    }
    
    var dolphinProfile: DolphinProfile?
    
    public static let CONSTANT_TYPE_IMAGE: String = "image"
    public static let CONSTANT_TYPE_DOCUMENT: String = "document"
    public static let CONSTANT_TYPE_OCTET_STREAM: String = "application/octet-stream"
    public static let CONSTANT_TYPE_APPLICATION: String = "application/pdf"
    public static let CONSTANT_TYPE_AUDIO: String = "audio"
    public static let CONSTANT_TYPE_VIDEO: String = "video"
    public static let CONSTANT_TYPE_TEXT: String = "text"
    
    // Singleton instance
    public static var shared = Connector()
    public init() {}
    
    /*
     Setup url, clientid, clientSecret, and optional generative config before starting connection
     */
    public func setupConnection(
        baseUrl: String,
        clientId: String,
        clientSecrect: String,
        botId: String? = nil,
        generativeBaseUrl: String? = nil,
        jwtToken: String? = nil,
        graphAuthUrl: String? = nil,
        graphUsername: String? = nil,
        graphPassword: String? = nil,
        channelId: String? = nil
    ) {
        self.baseUrl = baseUrl
        self.clientId = clientId
        self.clientSecrect = clientSecrect
        if let botId = botId, !botId.isEmpty {
            self.botId = botId
        }
        if let channelId = channelId, !channelId.isEmpty {
            self.channelId = channelId
        }
        if let generativeBaseUrl = generativeBaseUrl, !generativeBaseUrl.isEmpty {
            self.generativeBaseUrl = generativeBaseUrl
        }
        if let jwtToken = jwtToken, !jwtToken.isEmpty {
            self.jwtToken = jwtToken
        }
        if let graphAuthUrl = graphAuthUrl, !graphAuthUrl.isEmpty {
            self.graphAuthUrl = graphAuthUrl
        } else if let generativeBaseUrl = generativeBaseUrl, !generativeBaseUrl.isEmpty {
            self.graphAuthUrl = "\(generativeBaseUrl)/dolphin/apiv1/graph/auth"
        }
       if let graphUsername = graphUsername, !graphUsername.isEmpty {
           self.graphUsername = graphUsername
       }
       if let graphPassword = graphPassword, !graphPassword.isEmpty {
           self.graphPassword = graphPassword
       }
    }
    
    /*
     Enable or disable retrieving chat history on connect
     */
    public func enableGetQueue(isEnable: Bool) {
        self.isEnableQueue = isEnable
    }
    
    /*
     Construct connection after receiving user profile
     */
    public func constructConnector(profile: DolphinProfile) {
        dolphinProfile = profile
        getUserToken()
        authenticateGraph()
    }
    
    private var isAuthenticatingGraph: Bool = false
    private var pendingGraphAuthCompletions: [(_ success: Bool, _ token: String?) -> Void] = []
    private let graphAuthLock = NSLock()
    
    public func authenticateGraph(completion: ((_ success: Bool, _ token: String?) -> Void)? = nil) {
        graphAuthLock.lock()
        if let completion = completion {
            pendingGraphAuthCompletions.append(completion)
        }
        if isAuthenticatingGraph {
            graphAuthLock.unlock()
            return
        }
        isAuthenticatingGraph = true
        graphAuthLock.unlock()
        
        guard let url = URL(string: graphAuthUrl) else {
            print("[Graph Auth] URL endpoint auth tidak valid: \(graphAuthUrl)")
            notifyGraphAuthCompletions(success: false, token: nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "username": graphUsername,
            "password": graphPassword
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            guard let data = data, error == nil else {
                print("[Graph Auth] Error autentikasi:", error?.localizedDescription ?? "No data")
                self.notifyGraphAuthCompletions(success: false, token: nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String, !token.isEmpty {
                self.jwtToken = token
                print("[Graph Auth] Berhasil login & mendapatkan Bearer token untuk Generative Graph")
                self.notifyGraphAuthCompletions(success: true, token: token)
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let rawBody = String(data: data, encoding: .utf8) ?? ""
                print("[Graph Auth] Gagal login HTTP [\(statusCode)]: \(rawBody)")
                self.notifyGraphAuthCompletions(success: false, token: nil)
            }
        }.resume()
    }
    
    private func notifyGraphAuthCompletions(success: Bool, token: String?) {
        graphAuthLock.lock()
        let handlers = pendingGraphAuthCompletions
        pendingGraphAuthCompletions.removeAll()
        isAuthenticatingGraph = false
        graphAuthLock.unlock()
        
        for handler in handlers {
            handler(success, token)
        }
    }
    
    public func ensureGraphToken(completion: @escaping (_ token: String?) -> Void) {
        if let jwt = self.jwtToken, !jwt.isEmpty {
            completion(jwt)
            return
        }
        authenticateGraph { success, token in
            completion(token)
        }
    }
    
    /*
     Get user access and refresh token
     */
    public func getUserToken() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(rawValue: notificationConnectionStatus), object: 1)
        }
        authManager.getUserToken(baseUrl: baseUrl, clientId: clientId, clientSecret: clientSecrect) { [weak self] success in
            guard let self = self else { return }
            if success {
                self.doConnectToStomp()
            } else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name(rawValue: notificationConnectionStatus), object: 5)
                }
            }
        }
    }
    
    /*
     Refresh token
     */
    public func refreshAccessToken() {
        authManager.refreshAccessToken(baseUrl: baseUrl) { [weak self] success in
            guard let self = self, success else { return }
            self.doConnectToStomp()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name(rawValue: notificationConnectionStatus), object: 1)
            }
        }
    }
    
    /*
     Start WebSocket / STOMP connection
     */
    public func doConnectToStomp() {
        guard let dolphinProfile = dolphinProfile else { return }
        var tokenRef = token
        socketManager.doConnectToStomp(baseUrl: baseUrl, accessToken: access_token, dolphinProfile: dolphinProfile, token: &tokenRef)
        token = tokenRef
    }
    
    public func doDisconnectToWs() {
        socketManager.doDisconnectToWs()
    }
    
    public func doReconnectToWs() {
        socketManager.doReconnectToWs(accessToken: access_token, dolphinProfile: dolphinProfile)
    }
    
    public func subscribeMessage() {
        socketManager.subscribeMessage(accessToken: access_token, token: token)
    }
    
    public func unsubscribeMessage() {
        socketManager.unsubscribeMessage()
    }
    
    public func subscribeTransaction() {
        socketManager.subscribeTransaction(accessToken: access_token)
    }
    
    public func getChatHistory() {
        socketManager.getChatHistory(baseUrl: baseUrl, accessToken: access_token, dolphinProfile: dolphinProfile)
    }
    
    /*
     Send text message to web socket
     */
    public func onSendMessage(messages: String, dataUser: AnyObject? = nil) {
        var jsonString: Data?
        if dataUser != nil {
            jsonString = attachmentManager.convertDataToJson(data: dataUser as Any)
        }
        
        let messageItem = DolphinMessage()
        let tx = String(Int(NSDate().timeIntervalSince1970))
        messageItem.token = token
        messageItem.message = messages
        messageItem.transactionId = tx
        messageItem.messageHash = AESEncryption.MD5(cipherKey: messages)
        messageItem.sessionId = sessionId ?? ""
        messageItem.isUser = true
        messageItem.state = "message"
        messageItem.agentName = dolphinProfile?.name ?? ""
        messageItem.preCustomVar = jsonString
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: notificationMessage), object: messageItem)
        onSend(message: messageItem)
    }
    
    /*
     Send attachment file to server
     */
    public func sendAttachment(fileNsUrl: NSURL?, state: String, dataUser: AnyObject? = nil) {
        attachmentManager.sendAttachment(
            baseUrl: baseUrl,
            accessToken: access_token,
            clientSecret: clientSecrect,
            sessionId: sessionId,
            dolphinProfile: dolphinProfile,
            token: token,
            fileNsUrl: fileNsUrl,
            state: state,
            dataUser: dataUser,
            onSend: { [weak self] mediaMessage in
                self?.onSend(message: mediaMessage)
            }
        )
    }
    
    /*
     Send DolphinMessage via STOMP socket
     */
    public func onSend(message: DolphinMessage) {
        socketManager.onSend(message: message, accessToken: access_token, clientSecret: clientSecrect, attachmentManager: attachmentManager)
    }
    
    public func setEvent(msgDecriypted: DolphinMessage) {
        socketManager.setEvent(msgDecriypted: msgDecriypted)
    }
    
    public func incomingMessage(incomingMsg: DolphinMessage) {
        socketManager.incomingMessage(incomingMsg: incomingMsg)
    }
    
    public func setIncomingFileTypeAndState(message: DolphinMessage, state: String) {
        attachmentManager.setIncomingFileTypeAndState(message: message, state: state)
    }
    
    public func getUrlFile(url: String) -> String {
        let result: String = "\(url)?access_token=\(access_token)"
        print("attribute urlnya: ", result)
        return result
    }
    
    public func preRenderFileMessage(fileNsUrl: NSURL, state: String) -> DolphinMessage {
        return attachmentManager.preRenderFileMessage(token: token, sessionId: sessionId, dolphinProfile: dolphinProfile, fileNsUrl: fileNsUrl, state: state)
    }
    
    public func getMimeByState(state: String) -> String {
        return attachmentManager.getMimeByState(state: state)
    }
    
    public func convertToDataByMime(fileNsUrl: NSURL, mimeType: String) -> Data {
        return attachmentManager.convertToDataByMime(fileNsUrl: fileNsUrl, mimeType: mimeType)
    }
    
    public func getAttachmentURL(json: NSDictionary) -> String {
        return attachmentManager.getAttachmentURL(baseUrl: baseUrl, json: json)
    }
    
    public func convertDataToJson(data: Any) -> Data? {
        return attachmentManager.convertDataToJson(data: data)
    }
    
    public func parsingDataUserInformation(dataUser: Data) -> String? {
        return attachmentManager.parsingDataUserInformation(dataUser: dataUser)
    }
    
    public func convertDataToJsonString(arrayData: Any) -> String {
        return attachmentManager.convertDataToJsonString(arrayData: arrayData)
    }
    
    public func stompClient(client: StompClientLib!, didReceiveMessageWithJSONBody jsonBody: AnyObject?, akaStringBody stringBody: String?, withHeader header: [String : String]?, withDestination destination: String) {
        socketManager.stompClient(client: client, didReceiveMessageWithJSONBody: jsonBody, akaStringBody: stringBody, withHeader: header, withDestination: destination)
    }
    
    public func serverDidSendReceipt(client: StompClientLib!, withReceiptId receiptId: String) {
        socketManager.serverDidSendReceipt(client: client, withReceiptId: receiptId)
    }
    
    public func stompClientDidDisconnect(client: StompClientLib!) {
        socketManager.stompClientDidDisconnect(client: client)
    }
    
    public func stompClientDidConnect(client: StompClientLib!) {
        socketManager.stompClientDidConnect(client: client)
    }
    
    public func serverDidSendError(client: StompClientLib!, withErrorMessage description: String, detailedErrorMessage message: String?) {
        socketManager.serverDidSendError(client: client, withErrorMessage: description, detailedErrorMessage: message)
    }
    
    public func serverDidSendPing() {
        socketManager.serverDidSendPing()
    }
    
    public static let notificationHandleDeeplink = "DolphinLiveChatHandleDeeplink"
    
    public func handleDeeplink(url: URL) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: Connector.notificationHandleDeeplink), object: url)
    }
    
    @discardableResult
    public func startNewConversation() -> String {
        let newConvId = UUID().uuidString
        self.currentConversationId = newConvId
        return newConvId
    }
    
    public func endActiveSession(
        turnsToSave: [(question: String, answer: String)] = [],
        completion: ((_ success: Bool) -> Void)? = nil
    ) {
        let cid = self.currentConversationId
        let currentSid = self.sessionId
        doDisconnectToWs()
        
        if !turnsToSave.isEmpty {
            saveConversationTurns(turns: turnsToSave, conversationId: cid, sessionId: currentSid) { [weak self] allSucceeded in
                self?.socketManager.sessionId = nil
                self?.startNewConversation()
                print("Session ended and saved \(turnsToSave.count) turn(s) to conversation \(cid).")
                completion?(allSucceeded)
            }
        } else {
            socketManager.sessionId = nil
            startNewConversation()
            print("Session ended.")
            completion?(true)
        }
    }
    
    public func createGenerativeChat(
        id: String? = nil,
        question: String,
        answer: String,
        conversationId: String? = nil,
        firstChat: Bool = false,
        topic: String? = nil,
        topicIntention: [String] = [],
        sourceDocument: String? = nil,
        channelId: String? = nil,
        sessionId: String? = nil,
        botId: String? = nil,
        rawData: String = "",
        completion: ((_ success: Bool, _ error: Error?) -> Void)? = nil
    ) {
        let endpoint = "\(generativeBaseUrl)/dolphin/apiv1/graph/generative/chat"
        guard let url = URL(string: endpoint) else {
            completion?(false, NSError(domain: "CreateChatAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid endpoint URL"]))
            return
        }
        
        let cid = (conversationId != nil && !conversationId!.isEmpty) ? conversationId! : self.currentConversationId
        let bid = (botId != nil && !botId!.isEmpty) ? botId! : self.botId
        let sid = (sessionId != nil && !sessionId!.isEmpty) ? sessionId! : (self.sessionId ?? "")
        let chId = (channelId != nil && !channelId!.isEmpty) ? channelId! : self.channelId
        let messageId = (id != nil && !id!.isEmpty) ? id! : UUID().uuidString
        
        let resolvedTopic: String
        if let t = topic, !t.isEmpty {
            resolvedTopic = t
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "id_ID")
            dateFormatter.dateFormat = "d MMMM yyyy Jam saat ini: HH:mm:ss"
            let dateStr = dateFormatter.string(from: Date())
            let snippet = question.prefix(50)
            resolvedTopic = "Tanggal hari ini: \(dateStr) \(snippet)"
        }
        
        let body: [String: Any] = [
            "id": messageId,
            "answer": answer,
            "botId": bid,
            "question": question,
            "rawData": rawData,
            "sessionId": sid,
            "channelId": chId,
            "topic": resolvedTopic,
            "conversationId": cid,
            "firstChat": firstChat,
            "sourceDocument": sourceDocument ?? "null",
            "topicIntention": topicIntention
        ]
        
        ensureGraphToken { [weak self] token in
            guard let self = self, let tokenToSend = token, !tokenToSend.isEmpty else {
                print("[Create Chat API] Token autentikasi graph belum siap.")
                completion?(false, NSError(domain: "CreateChatAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Token autentikasi graph belum siap"]))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(tokenToSend)", forHTTPHeaderField: "Authorization")
            
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("[Create Chat API] Error saving chat turn:", error.localizedDescription)
                    completion?(false, error)
                } else if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    print("[Create Chat API] Chat turn saved successfully (convId: \(cid), firstChat: \(firstChat))")
                    completion?(true, nil)
                } else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let rawMsg = data != nil ? (String(data: data!, encoding: .utf8) ?? "") : ""
                    print("[Create Chat API] Respons error server HTTP [\(statusCode)]: \(rawMsg)")
                    let serverError = NSError(domain: "CreateChatAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode): \(rawMsg)"])
                    completion?(false, serverError)
                }
            }.resume()
        }
    }
    
    public func saveConversationTurns(
        turns: [(question: String, answer: String)] = [],
        conversationId: String? = nil,
        sessionId: String? = nil,
        botId: String? = nil,
        topic: String? = nil,
        completion: ((_ allSucceeded: Bool) -> Void)? = nil
    ) {
        let cid = (conversationId != nil && !conversationId!.isEmpty) ? conversationId! : self.currentConversationId
        let sid = (sessionId != nil && !sessionId!.isEmpty) ? sessionId! : (self.sessionId ?? "")
        let bid = (botId != nil && !botId!.isEmpty) ? botId! : self.botId
        
        // Inisialisasi percakapan baru jika turns masih kosong
        if turns.isEmpty {
            let resolvedTopic: String
            if let t = topic, !t.isEmpty {
                resolvedTopic = t
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "id_ID")
                dateFormatter.dateFormat = "d MMMM yyyy Jam saat ini: HH:mm:ss"
                let dateStr = dateFormatter.string(from: Date())
                resolvedTopic = "Tanggal hari ini: \(dateStr) Percakapan Baru"
            }
            
            createGenerativeChat(
                question: "",
                answer: "",
                conversationId: cid,
                firstChat: true,
                topic: resolvedTopic,
                sessionId: sid,
                botId: bid
            ) { success, _ in
                completion?(success)
            }
            return
        }
        
        // Simpan seluruh turn secara serial berurutan
        var allSuccess = true
        
        func sendNext(index: Int) {
            guard index < turns.count else {
                completion?(allSuccess)
                return
            }
            
            let turn = turns[index]
            let isFirst = (index == 0)
            
            createGenerativeChat(
                question: turn.question,
                answer: turn.answer,
                conversationId: cid,
                firstChat: isFirst,
                topic: (isFirst ? topic : nil),
                sessionId: sid,
                botId: bid
            ) { success, _ in
                if !success {
                    allSuccess = false
                }
                sendNext(index: index + 1)
            }
        }
        
        sendNext(index: 0)
    }
    
    public func updateFeedback(
        id: String,
        rating: String,
        ratingFeedback: String? = nil,
        completion: ((_ success: Bool, _ error: Error?) -> Void)? = nil
    ) {
        let endpoint = "\(generativeBaseUrl)/dolphin/apiv1/graph/generative/chat"
        guard let url = URL(string: endpoint) else {
            completion?(false, nil)
            return
        }
        
        ensureGraphToken { [weak self] token in
            guard let self = self, let tokenToSend = token, !tokenToSend.isEmpty else {
                print("[Feedback API] Token autentikasi graph belum siap.")
                completion?(false, NSError(domain: "FeedbackAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Token autentikasi graph belum siap"]))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(tokenToSend)", forHTTPHeaderField: "Authorization")
            
            var body: [String: Any] = [
                "id": id,
                "rating": rating
            ]
            if let feedback = ratingFeedback, !feedback.isEmpty {
                body["ratingFeedback"] = feedback
            }
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error updating feedback:", error.localizedDescription)
                    completion?(false, error)
                } else if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    print("Feedback updated successfully for id: \(id) [\(rating)]")
                    completion?(true, nil)
                } else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let rawMsg = data != nil ? (String(data: data!, encoding: .utf8) ?? "") : ""
                    print("[Feedback API] Respons dari server HTTP [\(statusCode)]: \(rawMsg)")
                    let serverError = NSError(domain: "FeedbackAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode)"])
                    completion?(false, serverError)
                }
            }.resume()
        }
    }

    public func submitMessageReaction(messageId: String, reaction: String) {
        let rating = (reaction.lowercased() == "thumbs_up" || reaction.lowercased() == "up") ? "up" : "down"
        updateFeedback(id: messageId, rating: rating)
    }

    private var favoriteMessages: [DolphinMessage] = []
    
    public func toggleFavorite(message: DolphinMessage) {
        message.isFavorite.toggle()
        if message.isFavorite {
            if !favoriteMessages.contains(where: { $0.transactionId == message.transactionId }) {
                favoriteMessages.append(message)
            }
            addFavoriteREST(message: message)
        } else {
            favoriteMessages.removeAll(where: { $0.transactionId == message.transactionId })
        }
    }
    
    public func getFavoriteMessages() -> [DolphinMessage] {
        return favoriteMessages
    }
    
    public func addFavoriteREST(message: DolphinMessage) {
        guard let url = URL(string: "\(baseUrl)/favourite/add") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "messageId": message.transactionId ?? "",
            "messageText": message.message ?? "",
            "sender": (message.isUser == true) ? "user" : "ai",
            "timestamp": Int(message.createdDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error adding favorite:", error.localizedDescription)
            }
        }.resume()
    }
    
    public func fetchFavorites(completion: @escaping ([DolphinMessage]) -> Void) {
        guard let url = URL(string: "\(baseUrl)/favourites") else {
            completion(getFavoriteMessages())
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                completion(self?.getFavoriteMessages() ?? [])
                return
            }
            if let list = try? JSONDecoder().decode([DolphinMessage].self, from: data) {
                self.favoriteMessages = list
                completion(list)
            } else {
                completion(self.getFavoriteMessages())
            }
        }.resume()
    }
    
    public func fetchConversations(
        sessionId: String? = nil,
        botId: String? = nil,
        completion: @escaping (_ list: [[String: Any]], _ errorMessage: String?) -> Void
    ) {
        let sid = (sessionId != nil && !sessionId!.isEmpty) ? sessionId! : (self.sessionId ?? "")
        let bid = (botId != nil && !botId!.isEmpty) ? botId! : self.botId
        
        ensureGraphToken { [weak self] token in
            guard let self = self, let tokenToSend = token, !tokenToSend.isEmpty else {
                completion([], "Token autentikasi graph belum siap.")
                return
            }
            
            var queryParams: [String] = ["botId=\(bid)"]
            if !sid.isEmpty {
                queryParams.insert("sessionId=\(sid)", at: 0)
            }
            let endpoint = "\(self.generativeBaseUrl)/dolphin/apiv1/graph/generative/history?\(queryParams.joined(separator: "&"))"
            
            guard let url = URL(string: endpoint) else {
                completion([], "URL endpoint tidak valid.")
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Bearer \(tokenToSend)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    completion([], error?.localizedDescription ?? "Koneksi gagal")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let rawStr = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                    let message: String
                    if httpResponse.statusCode == 401 {
                        message = "Otorisasi ditolak (HTTP 401 Unauthorized)."
                    } else if httpResponse.statusCode == 403 {
                        message = "Akses ditolak (HTTP 403 Forbidden)."
                    } else {
                        message = "Server error HTTP \(httpResponse.statusCode)"
                    }
                    print("[History API] HTTP Error [\(httpResponse.statusCode)]: \(rawStr)")
                    completion([], message)
                    return
                }
                
                if let jsonList = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    completion(jsonList, nil)
                    return
                }
                
                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let candidates = [
                        "data", "conversations", "conversationList", "history",
                        "histories", "result", "results", "items", "content", "chats", "messages"
                    ]
                    for key in candidates {
                        if let list = dict[key] as? [[String: Any]] {
                            completion(list, nil)
                            return
                        }
                    }
                    
                    // Cek nested dictionary (misal dict["data"]["content"] pada Spring Boot Page)
                    for parentKey in ["data", "result", "response"] {
                        if let nestedDict = dict[parentKey] as? [String: Any] {
                            for childKey in ["content", "items", "conversations", "list", "chats", "history"] {
                                if let list = nestedDict[childKey] as? [[String: Any]] {
                                    completion(list, nil)
                                    return
                                }
                            }
                        }
                    }
                }
                
                completion([], "Format respons JSON tidak dikenali.")
            }.resume()
        }
    }
    
    public func fetchConversations(
        sessionId: String? = nil,
        botId: String? = nil,
        completion: @escaping ([[String: Any]]) -> Void
    ) {
        fetchConversations(sessionId: sessionId, botId: botId) { list, _ in
            completion(list)
        }
    }
    
    public func fetchConversationChats(
        conversationId: String,
        sessionId: String? = nil,
        botId: String? = nil,
        completion: @escaping (_ chats: [[String: Any]], _ errorMessage: String?) -> Void
    ) {
        let sid = (sessionId != nil && !sessionId!.isEmpty) ? sessionId! : (self.sessionId ?? "")
        let bid = (botId != nil && !botId!.isEmpty) ? botId! : self.botId
        
        ensureGraphToken { [weak self] token in
            guard let self = self, let tokenToSend = token, !tokenToSend.isEmpty else {
                completion([], "Token autentikasi graph belum siap.")
                return
            }
            
            var queryParams: [String] = ["conversationId=\(conversationId)", "botId=\(bid)"]
            if !sid.isEmpty {
                queryParams.append("sessionId=\(sid)")
            }
            let endpoint = "\(self.generativeBaseUrl)/dolphin/apiv1/graph/generative/history?\(queryParams.joined(separator: "&"))"
            
            guard let url = URL(string: endpoint) else {
                completion([], "URL endpoint tidak valid.")
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Bearer \(tokenToSend)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    completion([], error?.localizedDescription ?? "Koneksi gagal")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let rawStr = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                    let message: String
                    if httpResponse.statusCode == 401 {
                        message = "Otorisasi ditolak (HTTP 401 Unauthorized)."
                    } else if httpResponse.statusCode == 403 {
                        message = "Akses ditolak (HTTP 403 Forbidden)."
                    } else {
                        message = "Server error HTTP \(httpResponse.statusCode)"
                    }
                    print("[History API] HTTP Error [\(httpResponse.statusCode)]: \(rawStr)")
                    completion([], message)
                    return
                }
                
                if let jsonList = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    completion(jsonList, nil)
                    return
                }
                
                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let candidates = [
                        "data", "chats", "messages", "conversation", "content", "items", "result", "history"
                    ]
                    for key in candidates {
                        if let list = dict[key] as? [[String: Any]] {
                            completion(list, nil)
                            return
                        }
                    }
                    
                    for parentKey in ["data", "result", "response"] {
                        if let nestedDict = dict[parentKey] as? [String: Any] {
                            for childKey in ["content", "items", "chats", "messages", "list", "history"] {
                                if let list = nestedDict[childKey] as? [[String: Any]] {
                                    completion(list, nil)
                                    return
                                }
                            }
                        }
                    }
                }
                
                completion([], "Format respons JSON tidak dikenali.")
            }.resume()
        }
    }

    
    public func fetchConversationChats(
        conversationId: String,
        sessionId: String? = nil,
        botId: String? = nil,
        completion: @escaping ([[String: Any]]) -> Void
    ) {
        fetchConversationChats(conversationId: conversationId, sessionId: sessionId, botId: botId) { chats, _ in
            completion(chats)
        }
    }

}

