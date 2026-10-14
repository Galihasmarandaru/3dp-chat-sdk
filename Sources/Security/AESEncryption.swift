//
//  AESEncryption.swift
//  imi-dolphin-livechat-ios
//

import Foundation
import CryptoSwift
import var CommonCrypto.CC_MD5_DIGEST_LENGTH
import func CommonCrypto.CC_MD5
import typealias CommonCrypto.CC_LONG

public class AESEncryption {
    
    /// Convert base64String to array [UInt8]
    public static func base64ToByteArray(base64String: String) -> [UInt8]? {
        guard !base64String.isEmpty else {
            print("String is empty")
            return nil
        }
        
        if let nsdata = NSData(base64Encoded: base64String, options: []) {
            var bytes = [UInt8](repeating: 0, count: nsdata.length)
            nsdata.getBytes(&bytes, length: nsdata.length)
            return bytes
        }
        return nil
    }
    
    /// Generate Random bytes
    public static func randomBytes(_ count: Int) -> Array<UInt8> {
        (0..<count).map({ _ in UInt8.random(in: 0...UInt8.max) })
    }
    
    /// Do decrypt
    public static func doDecrypt(clientSecret: String, accessToken: String, messageToDec: DolphinMessage) -> DolphinMessage? {
        guard !clientSecret.isEmpty, !accessToken.isEmpty else {
            return messageToDec
        }
        guard let iv = messageToDec.iv, !iv.isEmpty,
              let salt = messageToDec.salt, !salt.isEmpty else {
            return messageToDec
        }
        
        let cipherKey = (clientSecret + accessToken).md5()
        var decryptedMessage: DolphinMessage = DolphinMessage()
        
        decryptedMessage = decryptMessagePart1(decryptMessage: decryptedMessage, messageToDec: messageToDec, key: cipherKey)
        decryptedMessage = decryptMessagePart2(decryptMessage: decryptedMessage, messageToDec: messageToDec, key: cipherKey)
        decryptedMessage = decryptFile(decryptMessage: decryptedMessage, messageToDec: messageToDec, key: cipherKey)

        decryptedMessage.id = messageToDec.id ?? decryptedMessage.transactionId
        decryptedMessage.inbound = messageToDec.inbound
        decryptedMessage.outbound = messageToDec.outbound
        decryptedMessage.disconnect = messageToDec.disconnect
        decryptedMessage.attFilesize = messageToDec.attFilesize
        decryptedMessage.messageHash = messageToDec.messageHash
        decryptedMessage.latitude = messageToDec.latitude
        decryptedMessage.longitude = messageToDec.longitude
        decryptedMessage.createdDate = messageToDec.createdDate
        decryptedMessage.state = messageToDec.state
        decryptedMessage.messageType = messageToDec.messageType
        decryptedMessage.sourceDocument = messageToDec.sourceDocument
        decryptedMessage.summary = messageToDec.summary
        decryptedMessage.displayMessage = messageToDec.displayMessage
        decryptedMessage.documentId = messageToDec.documentId
        decryptedMessage.carouselItems = messageToDec.carouselItems
        decryptedMessage.actionButtons = messageToDec.actionButtons
        decryptedMessage.knowledgeSources = messageToDec.knowledgeSources
        decryptedMessage.reaction = messageToDec.reaction
        decryptedMessage.deeplinkUrl = messageToDec.deeplinkUrl
        decryptedMessage.isFavorite = messageToDec.isFavorite
        
        return decryptedMessage

    }
    
    /// Decrypt message part 1
    public static func decryptMessagePart1(decryptMessage: DolphinMessage, messageToDec: DolphinMessage, key: String) -> DolphinMessage {
        let iv = messageToDec.iv
        let salt = messageToDec.salt
        
        if messageToDec.agent != nil && !messageToDec.agent!.isEmpty {
            decryptMessage.agent = decrypt(message: messageToDec.agent!, iv: iv!, salt: salt!, key: key)
        }
        if messageToDec.agentAvatar != nil && !messageToDec.agentAvatar!.isEmpty {
            decryptMessage.agentAvatar = decrypt(message: messageToDec.agentAvatar!, iv: iv!, salt: salt!, key: key)
        }
        if messageToDec.agentName != nil && !messageToDec.agentName!.isEmpty {
            decryptMessage.agentName = decrypt(message: messageToDec.agentName!, iv: iv!, salt: salt!, key: key)
        }
        if messageToDec.message != nil && !messageToDec.message!.isEmpty {
            decryptMessage.message = decrypt(message: messageToDec.message!, iv: iv!, salt: salt!, key: key)
        }
        if messageToDec.token != nil && !messageToDec.token!.isEmpty {
            decryptMessage.token = decrypt(message: messageToDec.token!, iv: iv!, salt: salt!, key: key)
        }
        if messageToDec.sessionId != nil && !messageToDec.sessionId!.isEmpty {
            decryptMessage.sessionId = decrypt(message: messageToDec.sessionId!, iv: iv!, salt: salt!, key: key)
        }
        if messageToDec.attUrl != nil && !messageToDec.attUrl!.isEmpty {
            decryptMessage.attUrl = decrypt(message: messageToDec.attUrl!, iv: iv!, salt: salt!, key: key)
        }
        
        return decryptMessage
    }
    
    /// Decrypt message part 2
    public static func decryptMessagePart2(decryptMessage: DolphinMessage, messageToDec: DolphinMessage, key: String) -> DolphinMessage {
        let iv = messageToDec.iv
        let salt = messageToDec.salt
        
        if messageToDec.label != nil && !messageToDec.label!.isEmpty {
            decryptMessage.label = decrypt(message: messageToDec.label!, iv: iv!, salt: salt!, key: key)
        }
        if messageToDec.event != nil && !messageToDec.event!.isEmpty {
            decryptMessage.event = decrypt(message: messageToDec.event!, iv: iv!, salt: salt!, key: key)
        }
        if messageToDec.transactionId != nil && !messageToDec.transactionId!.isEmpty {
            decryptMessage.transactionId = decrypt(message: messageToDec.transactionId!, iv: iv!, salt: salt!, key: key)
        }
        
        return decryptMessage
    }
    
    /// Decrypt incoming attachment
    public static func decryptFile(decryptMessage: DolphinMessage, messageToDec: DolphinMessage, key: String) -> DolphinMessage {
        let iv = messageToDec.iv
        let salt = messageToDec.salt
        
        if messageToDec.attFilename != nil && !messageToDec.attFilename!.isEmpty {
            decryptMessage.attFilename = decrypt(message: messageToDec.attFilename!, iv: iv!, salt: salt!, key: key)
        }
        if messageToDec.attFiletype != nil && !messageToDec.attFiletype!.isEmpty {
            decryptMessage.attFiletype = decrypt(message: messageToDec.attFiletype!, iv: iv!, salt: salt!, key: key)
        }
        if messageToDec.attFilepath != nil && !messageToDec.attFilepath!.isEmpty {
            decryptMessage.attFilepath = decrypt(message: messageToDec.attFilepath!, iv: iv!, salt: salt!, key: key)
        }
        
        return decryptMessage
    }
    
    /// Decrypt message core
    public static func decrypt(message: String, iv: String, salt: String, key: String) -> String! {
        guard !message.isEmpty else {
            print("message is empty")
            return nil
        }
        
        let iteration = 1000
        let keyLength = 16
        let secretKey: [UInt8] = key.md5().bytes
        let newSalt = salt.replacingOccurrences(of: "\r\n", with: "", options: [.regularExpression, .caseInsensitive])
        let newIv = iv.replacingOccurrences(of: "\r\n", with: "", options: [.regularExpression, .caseInsensitive])
        let saltBytes: [UInt8] = base64ToByteArray(base64String: newSalt)!
        let ivBytes: [UInt8] = base64ToByteArray(base64String: newIv)!
        
        let messageData = Data(base64Encoded: message, options: .ignoreUnknownCharacters)
        var decryptedMessage: String?
        
        do {
            let key = try PKCS5.PBKDF2(
                password: secretKey,
                salt: saltBytes,
                iterations: iteration,
                keyLength: keyLength,
                variant: .sha1
            ).calculate()
            
            let aes = try AES(key: key, blockMode: CBC(iv: ivBytes), padding: .pkcs5)
            let decryptedBytes = try aes.decrypt(messageData!.bytes)
            let characters = decryptedBytes.map { Character(UnicodeScalar($0)) }
            
            decryptedMessage = String(Array(characters))
            print(decryptedMessage ?? "")
            return decryptedMessage
        } catch let error {
            print("Error with \(error)")
        }
        
        return decryptedMessage
    }
    
    /// Do encrypt
    public static func doEncrypt(clientSecret: String, message: DolphinMessage, accessToken: String) {
        do {
            let iterationCount = 1000
            let keySize = 16
            
            let chiperKey = (clientSecret + accessToken).md5()
            let secretKey: [UInt8] = chiperKey.md5().bytes
            
            let iv = randomBytes(16)
            print("IV Before: \(iv)")
            let ivString = Data(iv).base64EncodedString()
                        
            let newSalt = randomBytes(16)
            let saltString = Data(newSalt).base64EncodedString()
            
            let key = try PKCS5.PBKDF2(
                password: secretKey,
                salt: newSalt,
                iterations: iterationCount,
                keyLength: keySize,
                variant: .sha1
            ).calculate()
            
            doEncryptMessagePart1(msgToEncrypt: message, iv: iv, key: key, accessToken: accessToken)
            doEncryptMessagePart2(msgToEncrypt: message, iv: iv, key: key, accessToken: accessToken)
            doEncryptFile(msgToEncrypt: message, iv: iv, key: key, accessToken: accessToken)
            doEncryptCustomVariable(msgToEncrypt: message, iv: iv, key: key, accessToken: accessToken)
            
            message.iv = ivString
            message.salt = saltString
        } catch {
            print("Error encrypting message")
        }
    }
    
    /// Do encrypt message part 1
    public static func doEncryptMessagePart1(msgToEncrypt: DolphinMessage, iv: [UInt8], key: [UInt8], accessToken: String) {
        if msgToEncrypt.agent != nil && !msgToEncrypt.agent!.isEmpty {
            msgToEncrypt.agent = encrypt(message: msgToEncrypt.agent!, accessToken: accessToken, iv: iv, key: key)
        }
        if msgToEncrypt.agentAvatar != nil && !msgToEncrypt.agentAvatar!.isEmpty {
            msgToEncrypt.agentAvatar = encrypt(message: msgToEncrypt.agentAvatar!, accessToken: accessToken, iv: iv, key: key)
        }
        if msgToEncrypt.agentName != nil && !msgToEncrypt.agentName!.isEmpty {
            msgToEncrypt.agentName = encrypt(message: msgToEncrypt.agentName!, accessToken: accessToken, iv: iv, key: key)
        }
        if msgToEncrypt.message != nil && !msgToEncrypt.message!.isEmpty {
            msgToEncrypt.message = encrypt(message: msgToEncrypt.message!, accessToken: accessToken, iv: iv, key: key)
        }
        if msgToEncrypt.token != nil && !msgToEncrypt.token!.isEmpty {
            msgToEncrypt.token = encrypt(message: msgToEncrypt.token!, accessToken: accessToken, iv: iv, key: key)
        }
        if msgToEncrypt.transactionId != nil && !msgToEncrypt.transactionId!.isEmpty {
            msgToEncrypt.transactionId = encrypt(message: msgToEncrypt.transactionId!, accessToken: accessToken, iv: iv, key: key)
        }
        if msgToEncrypt.language != nil && !msgToEncrypt.language!.isEmpty {
            msgToEncrypt.language = encrypt(message: msgToEncrypt.language!, accessToken: accessToken, iv: iv, key: key)
        }
    }
    
    /// Do encrypt message part 2
    public static func doEncryptMessagePart2(msgToEncrypt: DolphinMessage, iv: [UInt8], key: [UInt8], accessToken: String) {
        if msgToEncrypt.event != nil && !msgToEncrypt.event!.isEmpty {
            msgToEncrypt.event = encrypt(message: msgToEncrypt.event!, accessToken: accessToken, iv: iv, key: key)
        }
        if msgToEncrypt.attUrl != nil && !msgToEncrypt.attUrl!.isEmpty {
            msgToEncrypt.attUrl = encrypt(message: msgToEncrypt.attUrl!, accessToken: accessToken, iv: iv, key: key)
        }
        if msgToEncrypt.sessionId != nil && !msgToEncrypt.sessionId!.isEmpty {
            msgToEncrypt.sessionId = encrypt(message: msgToEncrypt.sessionId!, accessToken: accessToken, iv: iv, key: key)
        }
    }
    
    /// Encrypt file details
    public static func doEncryptFile(msgToEncrypt: DolphinMessage, iv: [UInt8], key: [UInt8], accessToken: String) {
        if msgToEncrypt.attFilename != nil && !msgToEncrypt.attFilename!.isEmpty {
            msgToEncrypt.attFilename = encrypt(message: msgToEncrypt.attFilename!, accessToken: accessToken, iv: iv, key: key)
        }
        if msgToEncrypt.attFiletype != nil && !msgToEncrypt.attFiletype!.isEmpty {
            msgToEncrypt.attFiletype = encrypt(message: msgToEncrypt.attFiletype!, accessToken: accessToken, iv: iv, key: key)
        }
        if msgToEncrypt.attFilepath != nil && !msgToEncrypt.attFilepath!.isEmpty {
            msgToEncrypt.attFilepath = encrypt(message: msgToEncrypt.attFilepath!, accessToken: accessToken, iv: iv, key: key)
        }
    }
    
    /// Encrypt custom variable message
    public static func doEncryptCustomVariable(msgToEncrypt: DolphinMessage, iv: [UInt8], key: [UInt8], accessToken: String) {
        if msgToEncrypt.customVariables != nil && !msgToEncrypt.customVariables!.isEmpty {
            msgToEncrypt.customVariables = encrypt(message: msgToEncrypt.customVariables!, accessToken: accessToken, iv: iv, key: key)
        }
    }
    
    
    /// Encrypt given data
    public static func encrypt(message: String, accessToken: String, iv: Array<UInt8>, key: Array<UInt8>) -> String {
        do {
            let data: Data = message.data(using: .utf8)!
            let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs5)
            
            let encryptedBytes = try aes.encrypt(data.bytes)
            let encryptedData = Data(encryptedBytes)
            print("Encrypted data: " + encryptedData.toHexString())
            
            let messageChiper = encryptedData.base64EncodedString().data(using: .utf8)
            return String(decoding: messageChiper!, as: UTF8.self)
        } catch {
            print(error)
        }
        return ""
    }
    
    /// Generate MD5 hash string
    public static func MD5(cipherKey: String) -> String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)
        
        if let d = cipherKey.data(using: String.Encoding.utf8) {
            _ = d.withUnsafeBytes { (body: UnsafePointer<UInt8>) in
                CC_MD5(body, CC_LONG(d.count), &digest)
            }
        }
        return (0..<length).reduce("") {
            $0 + String(format: "%02x", digest[$1])
        }
    }
}
