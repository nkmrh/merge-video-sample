import Foundation
import AVFoundation

enum VideoMergerError: Error {
    case addVideoTrack
    case addAudioTrack
    case getVideoTrack
    case insertVideoTrack
    case insertAudioTrack
    case createExportSession
    case exportSession(Error?)
}

struct VideoMerger {
    static func merge(urls: [URL], completion: @escaping (URL?, Error?) -> ()) {
        let composition = AVMutableComposition()
        guard let trackA = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(nil, VideoMergerError.addVideoTrack)
            return
        }
        guard let trackB = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(nil, VideoMergerError.addAudioTrack)
            return
        }
        var videoCompositionInstractions: [AVMutableVideoCompositionInstruction] = []
        var currentTime = kCMTimeZero
        var videoSize: CGSize = .zero

        for url in urls {
            let asset = AVAsset(url: url)
            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                completion(nil, VideoMergerError.getVideoTrack)
                return
            }
            let audioTrack: AVAssetTrack? = asset.tracks(withMediaType: .audio).first
            do {
                try trackA.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: videoTrack, at: currentTime)
            } catch {
                completion(nil, VideoMergerError.insertVideoTrack)
                return
            }
            do {
                if let audioTrack = audioTrack {
                    try trackB.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: audioTrack, at: currentTime)
                } else {
                    trackB.insertEmptyTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration))
                }
            } catch {
                completion(nil, VideoMergerError.insertAudioTrack)
                return
            }

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: trackA)
            let videoCompositionInstraction = AVMutableVideoCompositionInstruction()
            videoCompositionInstraction.layerInstructions = [layerInstruction]
            videoCompositionInstraction.timeRange = CMTimeRangeMake(currentTime, asset.duration)

            videoCompositionInstractions.append(videoCompositionInstraction)

            currentTime = CMTimeAdd(currentTime, asset.duration)
            if videoSize.equalTo(.zero) {
                videoSize = videoTrack.naturalSize
            }
            if videoSize.height < videoTrack.naturalSize.height {
                videoSize.height = videoTrack.naturalSize.height
            }
            if videoSize.width < videoTrack.naturalSize.width {
                videoSize.width = videoTrack.naturalSize.width
            }
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTimeMake(1, 30)
        videoComposition.renderSize = videoSize
        videoComposition.instructions = videoCompositionInstractions


        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(nil, VideoMergerError.createExportSession)
            return
        }
        exporter.outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).mov")
        exporter.videoComposition = videoComposition
        exporter.outputFileType = .mov
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(exporter.outputURL, nil)
            case .cancelled, .failed:
                completion(nil, VideoMergerError.exportSession(exporter.error))
            default: break
            }
        }
    }
}
