//
//  SampleHandler.swift
//  ScreenStreamer
//
//  Created by Nikola Lukic on 5/7/20.
//  Copyright © 2020 Nikola Lukic. All rights reserved.
//
import Accelerate
import TwilioVideo
import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {
    // Video SDK components
    public var room: Room?
    var audioTrack: LocalAudioTrack?
    var videoSource: ReplayKitVideoSource?
    var screenTrack: LocalVideoTrack?
    var disconnectSemaphore: DispatchSemaphore?
//    let audioDevice = ExampleReplayKitAudioCapturer(sampleType: SampleHandler.kAudioSampleType)
    
    struct TokenResponse : Codable {
        var identity: String
        var token: String
    }
    
    var accessToken: String?
    let tokenUrl = "http://softarch.usc.edu:3000/token?identity=ios_device_"
    let deviceId = UIDevice.current.identifierForVendor!.uuidString
    let deviceType = UIDevice.current.name
    let setDeviceUrl = "http://192.168.1.126:3000/device"
    let deleteDeviceUrl = "http://192.168.1.126:3000/deletedevice"
    
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
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        do {
            accessToken = try SampleHandler.fetchToken(url: ((self.tokenUrl)+self.deviceId))
        } catch {
            let message = "Failed to fetch access token."
            print(message)
        }
        
        let telecineOptions = ReplayKitVideoSource.TelecineOptions.p60to24or25or30
        
        let (encodingParams, outputFormat) = ReplayKitVideoSource.getParametersForUseCase(codec: SampleHandler.kVideoCodec, isScreencast: true, telecineOptions: options)
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            // Handle video sample buffer
            break
        case RPSampleBufferType.audioApp:
            // Handle audio sample buffer for app audio
            break
        case RPSampleBufferType.audioMic:
            // Handle audio sample buffer for mic audio
            break
        @unknown default:
            // Handle other sample buffer types
            fatalError("Unknown type of sample buffer")
        }
    }
}
