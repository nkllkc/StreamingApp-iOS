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
    
    var accessToken: String = "TWILIO_ACCESS_TOKEN"
    let tokenUrl = "http://softarch.usc.edu:3000/token?identity=ios_device_"
    let deviceId = UIDevice.current.identifierForVendor!.uuidString
    let deviceType = UIDevice.current.name
    let setDeviceUrl = "http://softarch.usc.edu:3000/device"
    let deleteDeviceUrl = "http://softarch.usc.edu:3000/deletedevice"
    
    var statsTimer: Timer?
    static let kBroadcastSetupInfoRoomNameKey = "roomName"

    // Which kind of audio samples we will capture. The example does not mix multiple types of samples together.
//     static let kAudioSampleType = RPSampleBufferType.audioMic
    
    // The video codec to use for the broadcast. The encoding parameters and format request are built dynamically based upon the codec.
    static let kVideoCodec = H264Codec()!
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        if (accessToken == "TWILIO_ACCESS_TOKEN" || accessToken.isEmpty) {
            do {
                accessToken = try TokenUtils.fetchToken(url: ((self.tokenUrl)+self.deviceId))
            } catch {
                let message = "Failed to fetch access token."
                print(message)
            }
        }
        
        let telecineOptions = ReplayKitVideoSource.TelecineOptions.p60to24or25or30
        let (encodingParams, outputFormat) = ReplayKitVideoSource.getParametersForUseCase(codec: SampleHandler.kVideoCodec, isScreencast: true, telecineOptions: telecineOptions)
    
        self.videoSource = ReplayKitVideoSource(isScreencast: true, telecineOptions: telecineOptions)
        self.screenTrack = LocalVideoTrack(source: videoSource!, enabled: true, name: "Screen")
        
        videoSource!.requestOutputFormat(outputFormat)
        let connectOptions = ConnectOptions(token: self.accessToken) { (builder) in

                    // Use the local media that we prepared earlier.
//                    builder.audioTracks = [self.audioTrack!]
                    builder.videoTracks = [self.screenTrack!]

                    // We have observed that downscaling the input and using H.264 results in the lowest memory usage.
                    builder.preferredVideoCodecs = [SampleHandler.kVideoCodec]

                    /*
                     * Constrain the bitrate to improve QoS for subscribers when simulcast is not used, and to reduce overall
                     * bandwidth usage for the broadcaster.
                     */
                    builder.encodingParameters = encodingParams

                    /*
                     * A broadcast extension has no need to subscribe to Tracks, and connects as a publish-only
                     * Participant. In a Group Room, this options saves memory and bandwidth since decoders and receivers are
                     * no longer needed. Note that subscription events will not be raised for remote publications.
                     */
                    builder.isAutomaticSubscriptionEnabled = false

                    // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
                    // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
                    //            if #available(iOS 12.0, *) {
                    builder.roomName = "Room_" + self.deviceId;
                    //            } else {
                    //                builder.roomName = setupInfo?[SampleHandler.kBroadcastSetupInfoRoomNameKey] as? String
                    //            }
                }
        
        DeviceUtils.setDevice(url: setDeviceUrl, deviceId: self.deviceId ?? "", deviceType:self.deviceType)
        self.room = TwilioVideoSDK.connect(options: connectOptions, delegate: self)
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
//        self.audioTrack?.isEnabled = false
        self.screenTrack?.isEnabled = false
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
//        self.audioTrack?.isEnabled = true
        self.screenTrack?.isEnabled = true
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        DispatchQueue.main.async {
            self.room?.disconnect()
        }
        self.disconnectSemaphore?.wait()
        DispatchQueue.main.sync {
//            self.audioTrack = nil
            self.videoSource = nil
            self.screenTrack = nil
        }
        DeviceUtils.deleteDevice(url: self.deleteDeviceUrl, deviceId: self.deviceId)
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            videoSource?.processFrame(sampleBuffer: sampleBuffer)
            break

        case RPSampleBufferType.audioApp:
//            if (SampleHandler.kAudioSampleType == RPSampleBufferType.audioApp) {
//                ExampleCoreAudioDeviceCapturerCallback(audioDevice, sampleBuffer)
//            }
            break

        case RPSampleBufferType.audioMic:
//            if (SampleHandler.kAudioSampleType == RPSampleBufferType.audioMic) {
//                ExampleCoreAudioDeviceCapturerCallback(audioDevice, sampleBuffer)
//            }
            break
        }
    }
}

// MARK:- RoomDelegate
extension SampleHandler : RoomDelegate {
    func roomDidConnect(room: Room) {
        NSLog("didConnectToRoom: %s", room)

        disconnectSemaphore = DispatchSemaphore(value: 0)

        #if DEBUG
        statsTimer = Timer(fire: Date(timeIntervalSinceNow: 1), interval: 10, repeats: true, block: { (Timer) in
            room.getStats({ (reports: [StatsReport]) in
                for report in reports {
                    let videoStats = report.localVideoTrackStats.first!
                    print("Capture \(videoStats.captureDimensions) @ \(videoStats.captureFrameRate) fps.")
                    print("Send \(videoStats.dimensions) @ \(videoStats.frameRate) fps. RTT = \(videoStats.roundTripTime) ms")
                }
            })
        })

        if let theTimer = statsTimer {
            RunLoop.main.add(theTimer, forMode: .common)
        }
        #endif
    }

    func roomDidFailToConnect(room: Room, error: Error) {
        NSLog("room: %s, didFailToConnectWithError: %s", room, error.localizedDescription)
        finishBroadcastWithError(error)
    }

    func roomDidDisconnect(room: Room, error: Error?) {
        statsTimer?.invalidate()
        if let semaphore = self.disconnectSemaphore {
            semaphore.signal()
        }
        if let theError = error {
            NSLog("room: %s, roomDidDisconnect: %s", room, theError.localizedDescription)
            finishBroadcastWithError(theError)
        }
    }

    func roomIsReconnecting(room: Room, error: Error) {
        print("Reconnecting to room \(room.name), error = \(String(describing: error))")
    }

    func roomDidReconnect(room: Room) {
        print("Reconnected to room \(room.name)")
    }

    func participantDidConnect(room: Room, participant: RemoteParticipant) {
        print("participant: ", participant.identity, " didConnect")
    }

    func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        print("participant: ", participant.identity, " didDisconnect")
    }
}

