//
//  PhotoEditor+VideoExporter.swift
//  iOSPhotoEditor
//
//  Created by Mufakkharul Islam Nayem on 8/8/20.
//

import AVFoundation

extension PhotoEditorViewController {
    
    func exportAsVideo(onComplete: @escaping (URL?) -> Void) {
        if case .video(let videoURL) = self.media {
            
            let asset = AVURLAsset(url: videoURL)
            let composition = AVMutableComposition()
            
            guard
                let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                let assetTrack = asset.tracks(withMediaType: .video).first
                else {
                    print("Something is wrong with the asset.")
                    onComplete(nil)
                    return
            }
            
            do {
                let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
                try compositionTrack.insertTimeRange(timeRange, of: assetTrack, at: .zero)
                
                if let audioAssetTrack = asset.tracks(withMediaType: .audio).first,
                    let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try compositionAudioTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: .zero)
                }
            } catch {
                print(error)
                onComplete(nil)
                return
            }
            
            compositionTrack.preferredTransform = assetTrack.preferredTransform
            let videoInfo = orientation(from: assetTrack.preferredTransform)
            
            let videoSize: CGSize
            if videoInfo.isPortrait {
                videoSize = CGSize(width: assetTrack.naturalSize.height, height: assetTrack.naturalSize.width)
            } else {
                videoSize = assetTrack.naturalSize
            }
            
            let backgroundLayer = CALayer()
            backgroundLayer.frame = CGRect(origin: .zero, size: videoSize)
            let videoLayer = CALayer()
            videoLayer.frame = CGRect(origin: .zero, size: videoSize)
            let overlayLayer = CALayer()
            overlayLayer.frame = CGRect(origin: .zero, size: videoSize)
            
            backgroundLayer.backgroundColor = UIColor.red.cgColor
            videoLayer.frame = CGRect(x: 20, y: 20, width: videoSize.width - 40, height: videoSize.height - 40)
            
            add(image: canvasImageView.layerImage, to: overlayLayer, videoSize: videoSize)
            
            let outputLayer = CALayer()
            outputLayer.frame = CGRect(origin: .zero, size: videoSize)
            outputLayer.addSublayer(backgroundLayer)
            outputLayer.addSublayer(videoLayer)
            outputLayer.addSublayer(overlayLayer)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
            let layerInstruction = compositionLayerInstruction(for: compositionTrack, assetTrack: assetTrack)
            instruction.layerInstructions = [layerInstruction]
            
            let videoComposition = AVMutableVideoComposition()
            videoComposition.instructions = [instruction]
            videoComposition.renderSize = videoSize
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)    // 30 fps
            videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: outputLayer)
            
            guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
                else {
                    print("Cannot create export session.")
                    onComplete(nil)
                    return
            }
            
            let videoName = UUID().uuidString
            let exportURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(videoName)
                .appendingPathExtension("mov")
            
            export.videoComposition = videoComposition
            export.outputFileType = .mov
            export.outputURL = exportURL
            
            export.exportAsynchronously {
                DispatchQueue.main.async {
                    switch export.status {
                    case .completed:
                        onComplete(exportURL)
                    default:
                        print("Something went wrong during export.")
                        print(export.error ?? "unknown error")
                        onComplete(nil)
                        break
                    }
                }
            }
        } else {
            onComplete(nil)
        }
    }
    
    private func orientation(from transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        var assetOrientation = UIImage.Orientation.up
        var isPortrait = false
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            assetOrientation = .right
            isPortrait = true
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            assetOrientation = .left
            isPortrait = true
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            assetOrientation = .up
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            assetOrientation = .down
        }
        
        return (assetOrientation, isPortrait)
    }
    
    private func add(image: UIImage, to layer: CALayer, videoSize: CGSize) {
        let imageLayer = CALayer()
        /*
        // commented out the code used as here: https://www.raywenderlich.com/6236502-avfoundation-tutorial-adding-overlays-and-animations-to-videos
        // because it doesn't play well with wide videos
        let aspect: CGFloat = image.size.width / image.size.height
        let width = videoSize.width
        let height = width / aspect
        imageLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        */
        imageLayer.frame = layer.frame
        imageLayer.contents = image.cgImage
        imageLayer.contentsGravity = .resizeAspectFill  // check .resizeAspect too
        layer.addSublayer(imageLayer)
    }
    
    private func compositionLayerInstruction(for track: AVCompositionTrack, assetTrack: AVAssetTrack) -> AVMutableVideoCompositionLayerInstruction {
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let transform = assetTrack.preferredTransform
        
        instruction.setTransform(transform, at: .zero)
        
        return instruction
    }
    
}

extension FileManager {
    func removeFileIfNecessary(at url: URL) throws {
        guard fileExists(atPath: url.path) else { return }
        try removeItem(at: url)
    }
}
