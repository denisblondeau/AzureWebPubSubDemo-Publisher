//
//  PubModel.swift
//  Publisher
//
//  Created by Denis Blondeau on 2022-12-19.
//

import AppKit
import SwiftJWT

final class PubModel: NSObject, ObservableObject {
    
    @Published var activityInformation = ""
    @Published var messageReceived = ""
    
    private var webSocket: URLSessionWebSocketTask!
    //Set to true when webSocket is active.
    private(set) var isOpen = false
    
    // Host name from your Web PubSub Service keys (in "Settings") - Microsft Azure portal (portal.azure.com)
    private var hostname = ""
    // secret = Access key (primary or secondary) from your Web PubSub Service keys (in "Settings") - Microsft Azure portal (portal.azure.com)
    private var secret = ""
    
    // The next two variables have to match the variables in your Subscriber.
    private var hub = "DemoHub"
    private var group = "DemoGroup"
    
    private var hubURL: String {
        get {
            return  "wss://\(hostname)/client/hubs/\(hub)"
        }
    }
    
    private var ackId = 1
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate(notification:)), name: NSApplication.willTerminateNotification, object: nil)
        
        // If hostname is empty, try to get it from the local secure key file - file that is not distributed on GitHub.
        if hostname.isEmpty {
            hostname = Bundle.main.infoDictionary?["AZURE_HOSTNAME"] as? String ?? ""
        }
        
        // If secret is empty, try to get it from the local secure key file - file that is not distributed on GitHub.
        if secret.isEmpty {
            secret = Bundle.main.infoDictionary?["AZURE_ACCESS_KEY"] as? String ?? ""
        }
        
        openWebSocket()
    }
    
    // Clean up before app terminates.
    @objc private func appWillTerminate(notification: NSNotification) {
        
        // Close webSocket if open.
        if isOpen {
            webSocket.cancel(with: .goingAway, reason: nil)
            webSocket = nil
            isOpen = false
        }
    }
    
    private func getSignedJWT() -> String? {
        
        struct MyClaims: Claims {
            let aud: String
            let exp: Date
            let roles: [String]
        }
        
        let header = Header()
        // "The exp(iration) of the access token is only checked at the time you're making the new connection. In particular, the service won't terminate the connection if the access token expires after connection is connected." (see: https://github.com/Azure/azure-webpubsub/blob/main/protocols/client/client-spec.md)
        let claims = MyClaims(aud: hubURL,
                              exp: Date(timeIntervalSinceNow: 60),
                              roles: [Permission.sendToGroup(group).role])
        var myJWT = JWT(header: header, claims: claims)
        let privateKey = Data(secret.utf8)
        let signer = JWTSigner.hs256(key: privateKey)
        guard let signedJWT = try? myJWT.sign(using: signer) else {
            updateMessage(activityInformation: "Error: Cannot sign JSON Web Token.")
            return nil
        }
        
        return signedJWT
    }
    
    private func openWebSocket() {
        
        guard let url = URL(string: hubURL)  else {
            updateMessage(activityInformation: "* Invalid hubURL *")
            return
        }
        
        guard let signedJWT = getSignedJWT() else {
            updateMessage(activityInformation: "* Cannot generate signed JWT *")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(signedJWT)", forHTTPHeaderField: "Authorization")
        request.setValue(Subprotocol.json.rawValue, forHTTPHeaderField: "Sec-WebSocket-Protocol")
        
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocket = session.webSocketTask(with: request)
        webSocket.resume()
        
    }
    
    func sendMessage(_ message: String) {
        let request = Request.sendToGroup(group: group, ackId: ackId, dataType: DataType.text, data: message).value
        guard let jsonData = try? JSONSerialization.data(withJSONObject: request) else { return }
        ackId += 1
        webSocket.send(URLSessionWebSocketTask.Message.data(jsonData)) { error  in
            if let error {
                self.updateMessage(activityInformation: "* Failed sending 'send to group' request:  \(error.localizedDescription) *")
            } else {
                self.updateMessage(activityInformation: "* Successfully sent 'send to group' request *")
            }
        }
    }
    
    private func receiveMessages() {
        
        webSocket.receive { result in
            
            switch result {
                
            case .failure(let error):
                self.updateMessage(activityInformation: "* Error receiving message: \(error.localizedDescription) *")
                return
                
            case .success(let message):
                
                switch message {
                    
                case .string(let string):
                    if let ack = try? JSONDecoder().decode(Ack.self, from: Data(string.utf8)) {
                        if !ack.success {
                            if let error = ack.error {
                                self.updateMessage(messageReceived: "* Error: \(error.name) -> Message: \(error.message) *")
                            }
                        }
                    } else if let msg = try? JSONDecoder().decode(Message.self, from: Data(string.utf8)) {
                        self.updateMessage(messageReceived: msg.data)
                    } else {
                        self.updateMessage(messageReceived: string)
                    }
                    
                case .data(let data):
                    self.updateMessage(messageReceived: data.description)
                    
                default:
                    self.updateMessage(messageReceived: "* Unknown data received *" )
                }
            }
            self.receiveMessages()
        }
    }
    
    private func updateMessage(activityInformation: String = "", messageReceived: String = "") {
        
        let formattedDate = Date().formatted(
            .dateTime.hour().minute().second().secondFraction(.fractional(3))
        )
        DispatchQueue.main.async {
            if activityInformation.isEmpty {
                self.messageReceived += formattedDate + ": " + messageReceived + "\n\n"
            } else {
                self.activityInformation += formattedDate + ": " + activityInformation + "\n\n"
            }
        }
    }
}

extension PubModel: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        updateMessage(activityInformation: "* Web socket is open *")
        isOpen = true
        receiveMessages()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        updateMessage(activityInformation: "* Web socket closed *")
        isOpen = false
    }
}
