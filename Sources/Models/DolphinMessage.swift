//
//  DolphinMessage.swift
//  imi-dolphin-livechat-ios
//

import Foundation

public class DolphinMessage: Codable {
    
    public init(id: String? = nil, agent: String? = nil, agentAvatar: String? = nil, agentName: String? = nil, attFilename: String? = nil, attFilepath: String? = nil, attFilesize: Int? = nil, attFiletype: String? = nil, attUrl: String? = nil, customVariables: String? = nil, disconnect: Bool? = nil, event: String? = nil, inbound: Bool? = nil, iv: String? = nil, label: String? = nil, language: String? = nil, latitude: String? = nil, longitude: String? = nil, message: String? = nil, messageHash: String? = nil, outbound: Bool? = nil, salt: String? = nil, sessionId: String? = nil, token: String? = nil, transactionId: String? = nil, isUser: Bool? = nil, createdDate: Date? = nil, state: String? = nil, preCustomVar: Data? = nil) {
        
        self.id = id ?? transactionId
        self.agent = agent
        self.agentAvatar = agentAvatar
        self.agentName = agentName
        self.attFilename = attFilename
        self.attFilepath = attFilepath
        self.attFilesize = attFilesize
        self.attFiletype = attFiletype
        self.attUrl = attUrl
        self.customVariables = customVariables
        self.disconnect = disconnect
        self.event = event
        self.inbound = inbound
        self.iv = iv
        self.label = label
        self.language = language
        self.latitude = latitude
        self.longitude = longitude
        self.message = message
        self.messageHash = messageHash
        self.outbound = outbound
        self.salt = salt
        self.sessionId = sessionId
        self.token = token
        self.transactionId = transactionId
        self.isUser = isUser
        self.createdDate = createdDate
        self.state = state
        self.preCustomVar = preCustomVar
    }
    
    public var id: String?
    public var agent: String?
    public var agentAvatar: String?
    public var agentName: String?
    public var attFilename: String?
    public var attFilepath: String?
    public var attFilesize: Int?
    public var attFiletype: String?
    public var attUrl: String?
    public var customVariables: String?
    public var disconnect: Bool?
    public var event: String?
    public var inbound: Bool?
    public var iv: String?
    public var label: String?
    public var language: String?
    public var latitude: String?
    public var longitude: String?
    public var message: String?
    public var messageHash: String?
    public var outbound: Bool?
    public var salt: String?
    public var sessionId: String?
    public var token: String?
    public var transactionId: String?
    public var isUser: Bool?
    public var createdDate: Date?
    public var state: String?
    public var preCustomVar: Data?
    
    // Server Streaming & Metadata Keys
    public var messageType: String?
    public var sourceDocument: String?
    public var summary: String?
    public var displayMessage: String?
    public var documentId: String?
    
    // MARK: - Button Carousel & Deeplink Mechanism
    public var carouselItems: [CarouselItem]?
    public var actionButtons: [ActionButton]?
    public var deeplinkUrl: String?
    
    // MARK: - Reaction Bar
    public var reaction: String? // e.g. "thumbs_up", "thumbs_down"

    // MARK: - Source Knowledge Display
    public var knowledgeSources: [KnowledgeSource]? // e.g. title, url, snippet
    
    // MARK: - Favorites and Chat History
    public var isFavorite: Bool = false

    public enum CodingKeys: String, CodingKey {
        case id
        case agent, agentAvatar, agentName, attFilename, attFilepath, attFilesize, attFiletype, attUrl
        case customVariables, disconnect, event, inbound, iv, label, language, latitude, longitude
        case message, messageHash, outbound, salt, sessionId, token, transactionId, isUser, createdDate, state
        case messageType, sourceDocument, summary, displayMessage, documentId
        case isFavorite, reaction, deeplinkUrl, carouselItems, actionButtons, knowledgeSources
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? (try? container.decodeIfPresent(String.self, forKey: .transactionId))
        self.agent = try container.decodeIfPresent(String.self, forKey: .agent)
        self.agentAvatar = try container.decodeIfPresent(String.self, forKey: .agentAvatar)
        self.agentName = try container.decodeIfPresent(String.self, forKey: .agentName)
        self.attFilename = try container.decodeIfPresent(String.self, forKey: .attFilename)
        self.attFilepath = try container.decodeIfPresent(String.self, forKey: .attFilepath)
        self.attFilesize = try container.decodeIfPresent(Int.self, forKey: .attFilesize)
        self.attFiletype = try container.decodeIfPresent(String.self, forKey: .attFiletype)
        self.attUrl = try container.decodeIfPresent(String.self, forKey: .attUrl)
        self.customVariables = try container.decodeIfPresent(String.self, forKey: .customVariables)
        self.disconnect = try container.decodeIfPresent(Bool.self, forKey: .disconnect)
        self.event = try container.decodeIfPresent(String.self, forKey: .event)
        self.inbound = try container.decodeIfPresent(Bool.self, forKey: .inbound)
        self.iv = try container.decodeIfPresent(String.self, forKey: .iv)
        self.label = try container.decodeIfPresent(String.self, forKey: .label)
        self.language = try container.decodeIfPresent(String.self, forKey: .language)
        self.latitude = try container.decodeIfPresent(String.self, forKey: .latitude)
        self.longitude = try container.decodeIfPresent(String.self, forKey: .longitude)
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.messageHash = try container.decodeIfPresent(String.self, forKey: .messageHash)
        self.outbound = try container.decodeIfPresent(Bool.self, forKey: .outbound)
        self.salt = try container.decodeIfPresent(String.self, forKey: .salt)
        self.sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        self.token = try container.decodeIfPresent(String.self, forKey: .token)
        self.transactionId = try container.decodeIfPresent(String.self, forKey: .transactionId)
        if self.id == nil {
            self.id = self.transactionId
        }
        self.isUser = try container.decodeIfPresent(Bool.self, forKey: .isUser)
        self.createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate)
        self.state = try container.decodeIfPresent(String.self, forKey: .state)
        
        self.messageType = try container.decodeIfPresent(String.self, forKey: .messageType)
        self.sourceDocument = try container.decodeIfPresent(String.self, forKey: .sourceDocument)
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary)
        self.displayMessage = try container.decodeIfPresent(String.self, forKey: .displayMessage)
        self.documentId = try container.decodeIfPresent(String.self, forKey: .documentId)
        
        self.isFavorite = (try? container.decodeIfPresent(Bool.self, forKey: .isFavorite)) ?? false
        self.reaction = try container.decodeIfPresent(String.self, forKey: .reaction)
        self.deeplinkUrl = try container.decodeIfPresent(String.self, forKey: .deeplinkUrl)
        self.carouselItems = try container.decodeIfPresent([CarouselItem].self, forKey: .carouselItems)
        self.actionButtons = try container.decodeIfPresent([ActionButton].self, forKey: .actionButtons)
        self.knowledgeSources = try container.decodeIfPresent([KnowledgeSource].self, forKey: .knowledgeSources)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(agent, forKey: .agent)
        try container.encodeIfPresent(agentAvatar, forKey: .agentAvatar)
        try container.encodeIfPresent(agentName, forKey: .agentName)
        try container.encodeIfPresent(attFilename, forKey: .attFilename)
        try container.encodeIfPresent(attFilepath, forKey: .attFilepath)
        try container.encodeIfPresent(attFilesize, forKey: .attFilesize)
        try container.encodeIfPresent(attFiletype, forKey: .attFiletype)
        try container.encodeIfPresent(attUrl, forKey: .attUrl)
        try container.encodeIfPresent(customVariables, forKey: .customVariables)
        try container.encodeIfPresent(disconnect, forKey: .disconnect)
        try container.encodeIfPresent(event, forKey: .event)
        try container.encodeIfPresent(inbound, forKey: .inbound)
        try container.encodeIfPresent(iv, forKey: .iv)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(messageHash, forKey: .messageHash)
        try container.encodeIfPresent(outbound, forKey: .outbound)
        try container.encodeIfPresent(salt, forKey: .salt)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(token, forKey: .token)
        try container.encodeIfPresent(transactionId, forKey: .transactionId)
        try container.encodeIfPresent(isUser, forKey: .isUser)
        try container.encodeIfPresent(createdDate, forKey: .createdDate)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(messageType, forKey: .messageType)
        try container.encodeIfPresent(sourceDocument, forKey: .sourceDocument)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(displayMessage, forKey: .displayMessage)
        try container.encodeIfPresent(documentId, forKey: .documentId)
        try container.encodeIfPresent(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(reaction, forKey: .reaction)
        try container.encodeIfPresent(deeplinkUrl, forKey: .deeplinkUrl)
        try container.encodeIfPresent(carouselItems, forKey: .carouselItems)
        try container.encodeIfPresent(actionButtons, forKey: .actionButtons)
        try container.encodeIfPresent(knowledgeSources, forKey: .knowledgeSources)
    }
    
    public static func parsingHistoryToMessage(chatMessage: DolphinChatHistory, filename: String? = nil, attachmentUrl: String? = nil, state: String) -> DolphinMessage {
        let epochTime = TimeInterval((chatMessage.createdDate ?? 0) / 1000)
        let isUser = !(chatMessage.answer ?? false)
        let dolphinMessage = DolphinMessage(
            id: chatMessage.id ?? chatMessage.messageID ?? chatMessage.transactionID,
            agentName: isUser ? chatMessage.accountName : chatMessage.replyAgent,
            attFilename: filename,
            attFiletype: (chatMessage.message != nil && chatMessage.message != "") ? nil : state,
            attUrl: attachmentUrl,
            message: (chatMessage.message != nil && chatMessage.message != "") ? chatMessage.message : nil,
            transactionId: chatMessage.transactionID,
            isUser: isUser,
            createdDate: Date(timeIntervalSince1970: epochTime),
            state: state
        )
        return dolphinMessage
    }
}

public struct ActionButton: Codable {
    public var label: String?
    public var type: String?
    public var payload: String?
    
    public init(label: String? = nil, type: String? = nil, payload: String? = nil) {
        self.label = label
        self.type = type
        self.payload = payload
    }
}

public struct CarouselItem: Codable {
    public var title: String?
    public var description: String?
    public var imageUrl: String?
    public var buttons: [ActionButton]?
    
    public init(title: String? = nil, description: String? = nil, imageUrl: String? = nil, buttons: [ActionButton]? = nil) {
        self.title = title
        self.description = description
        self.imageUrl = imageUrl
        self.buttons = buttons
    }
}

public struct KnowledgeSource: Codable {
    public var title: String?
    public var snippet: String?
    public var url: String?
    
    public init(title: String? = nil, snippet: String? = nil, url: String? = nil) {
        self.title = title
        self.snippet = snippet
        self.url = url
    }
}
