//
//  ScreenCapturer.swift
//  Nimble
//
//  Created by Andrii Novoselskyi on 27.07.2020.
//

import Foundation
import ReplayKit

public class ScreenCapturer {
    
    public var isMicrophoneEnabled: Bool = false
    
    public var isRecording: Bool {
        return recorder.isRecording
    }
    
    private var recorder: RPScreenRecorder = RPScreenRecorder.shared()
    
    private var assetWriter: AVAssetWriter?
    private var videoURL: URL?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    
    public init() {}
}

extension ScreenCapturer {
    
    public func startCapture(scale: CGFloat = UIScreen.main.scale, completion: ((Error) -> Void)? = nil) {
        guard let videosDirectoryUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let exists = FileManager.default.fileExists(atPath: videosDirectoryUrl.path)
        
        if !exists {
            do {
                try FileManager.default.createDirectory(at: videosDirectoryUrl, withIntermediateDirectories: true, attributes: nil)
            } catch { completion?(error); return }
        }
        
        let fullVideoUrl = videosDirectoryUrl.appendingPathComponent("\(UUID().uuidString).mp4")
        self.videoURL = fullVideoUrl

        try? FileManager.default.removeItem(at: fullVideoUrl)

        do {
            try assetWriter = AVAssetWriter(outputURL: fullVideoUrl, fileType: .mp4)
        } catch { completion?(error); return }

        var screenBounds = UIScreen.main.bounds
        screenBounds.size.width *= scale
        screenBounds.size.height *= scale
        if screenBounds.size.width.truncatingRemainder(dividingBy: 2) != 0 {
            screenBounds.size.width += 1
        }
        if screenBounds.size.height.truncatingRemainder(dividingBy: 2) != 0 {
            screenBounds.size.height += 1
        }
        let videoSettings: [String : Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: screenBounds.width,
            AVVideoHeightKey: screenBounds.height
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        if assetWriter?.canAdd(videoInput) == true {
            assetWriter?.add(videoInput)
        }
        self.videoInput = videoInput

        let audioSettings: [String : Any] = [
            AVFormatIDKey : kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey : 2,
            AVSampleRateKey : 44100.0,
            AVEncoderBitRateKey: 192000
        ]

        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        if assetWriter?.canAdd(audioInput) == true {
            assetWriter?.add(audioInput)
        }
        self.audioInput = audioInput

        guard recorder.isAvailable else { completion?(CapturerError.generic); return }
        recorder.isMicrophoneEnabled = isMicrophoneEnabled
                
        recorder.startCapture(handler: { [weak self] cmSampleBuffer, rpSampleBufferType, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion?(error);
                }
                return
            }
            
            if CMSampleBufferDataIsReady(cmSampleBuffer) {
                DispatchQueue.main.async {
                    switch rpSampleBufferType {
                    case .video:
                        if self?.assetWriter?.status == .unknown {
                            self?.assetWriter?.startWriting()
                            self?.assetWriter?.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(cmSampleBuffer))
                        }

                        if self?.assetWriter?.status == .failed {
                            let error = self?.assetWriter?.error ?? CapturerError.generic
                            completion?(error)
                            return
                        }

                        if self?.assetWriter?.status == .writing {
                            if self?.videoInput?.isReadyForMoreMediaData == true {
                                self?.videoInput?.append(cmSampleBuffer)
                            }
                        }

                    case .audioMic:
                        if self?.audioInput?.isReadyForMoreMediaData == true {
                            self?.audioInput?.append(cmSampleBuffer)
                        }

                    default:
                        break
                    }
                }
            }
        }, completionHandler: { error in
            if let error = error {
                DispatchQueue.main.async {
                    completion?(error)
                }
                return
            }
        })
    }
    
    public func stopCapture(completion: ((Result<URL, Error>) -> Void)? = nil) {
        recorder.stopCapture { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
                return
            }

            self?.videoInput?.markAsFinished()
            self?.audioInput?.markAsFinished()
            self?.assetWriter?.finishWriting {
                DispatchQueue.main.async {
                    if let videoURL = self?.videoURL {
                        completion?(.success(videoURL))
                    } else {
                        completion?(.failure(CapturerError.generic))
                    }
                }
            }
        }
    }
}
