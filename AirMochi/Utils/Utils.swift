//
//  Utils.swift
//
//  Copyright © 2016-2019 Twilio, Inc. All rights reserved.
//

import Foundation
import os

// Helper to determine if we're running on simulator or device
struct PlatformUtils {
    static let isSimulator: Bool = {
        var isSim = false
        #if arch(i386) || arch(x86_64)
            isSim = true
        #endif
        return isSim
    }()
}

struct TokenResponse : Codable {
    var identity: String
    var token: String
}

struct TokenUtils {
    static func fetchToken(url : String) throws -> String {
        var token: String = "TWILIO_ACCESS_TOKEN"
        let requestURL: URL = URL(string: url)!
        os_log("fetching token.")
        do {
            let data = try Data(contentsOf: requestURL)
            let decoder = JSONDecoder()
            let model = try decoder.decode(TokenResponse.self, from: data) //Decode JSON Response Data
            os_log("Token: %@", log: OSLog.default, type: .error, model.token)
            token = model.token
        } catch let error as NSError {
            print ("Invalid token url, error = \(error)")
            throw error
        }
        return token
    }
}

struct DeviceUtils {
    static func setDevice(url: String, deviceId: String, deviceType: String) {
        print("in setDevice function")
        let requestURL: URL = URL(string:url)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        let parameters: [String: Any] = [
            "deviceId": deviceId,
            "deviceType": deviceType
        ]
        
        do {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        } catch {
            print("cannot serialize parameters.")
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                let response = response as? HTTPURLResponse,
                error == nil else {
                print("error", error ?? "Unknown error")
                return
            }
            let responseString = String(data: data, encoding: .utf8)
            print("responseString = \(String(describing: responseString))")
        }
        
        task.resume()
    }
    
    static func deleteDevice(url: String, deviceId: String){
        print("in deleteDevice function")
        let requestURL: URL = URL(string:url)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        
        let parameters: [String: Any] = [
            "deviceId": deviceId
        ]
        
        do {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        } catch {
            print("cannot serialize parameters.")
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                let response = response as? HTTPURLResponse,
                error == nil else {
                print("error", error ?? "Unknown error")
                return
            }
            
            let responseString = String(data: data, encoding: .utf8)
            print("responseString = \(String(describing: responseString))")
        }
        
        task.resume()
    }
}
