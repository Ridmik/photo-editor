//
//  PhotoEditor+VideoExporter.swift
//  iOSPhotoEditor
//
//  Created by Mufakkharul Islam Nayem on 8/8/20.
//

import AVFoundation

extension PhotoEditorViewController {
    // This implementation is a combination of below two:
    // https://www.raywenderlich.com/6236502-avfoundation-tutorial-adding-overlays-and-animations-to-videos
    // https://www.raywenderlich.com/10857372-how-to-play-record-and-merge-videos-in-ios-and-swift
    func exportAsVideo(onComplete: @escaping (URL?) -> Void) {
        if case .video(let videoURL) = self.media {
            
            let asset = AVURLAsset(url: videoURL)
            let mixComposition = AVMutableComposition()
            
            guard let compositionTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
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
                    let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try compositionAudioTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: .zero)
                }
            } catch {
                print(error)
                onComplete(nil)
                return
            }
            
            let videoSize = view.bounds.size    // logical size of video shown on screen
            let scale = UIScreen.main.scale
            let renderSize = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
            // FIXME: Not sure if this 44 value is correct for all device sizes. May need to replace with the height of navigation bar.
            let topOffset = 44 * scale
            
            // Composition Instructions
            let compositionInstruction = AVMutableVideoCompositionInstruction()
            compositionInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
            
            // Set up the layer instruction
            let layerInstruction = videoCompositionLayerInstruction(compositionTrack: compositionTrack, assetTrack: assetTrack, renderSize: renderSize, topOffset: topOffset)
            
            // Add layer instruction to composition instruction and create a mutable video composition
            compositionInstruction.layerInstructions = [layerInstruction]
            
            let videoComposition = AVMutableVideoComposition()
            videoComposition.instructions = [compositionInstruction]
            videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
            videoComposition.renderSize = renderSize
            
            // prepare canvas layer
            let backgroundLayer = CALayer()
            backgroundLayer.frame = CGRect(origin: .zero, size: renderSize)
            let videoLayer = CALayer()
            videoLayer.frame = CGRect(origin: .zero, size: renderSize)
            let overlayLayer = CALayer()
            overlayLayer.frame = CGRect(origin: .zero, size: renderSize)
            
            add(image: canvasImageView.layerImage, to: overlayLayer)
            
            let outputLayer = CALayer()
            outputLayer.frame = CGRect(origin: .zero, size: renderSize)
            outputLayer.addSublayer(backgroundLayer)
            outputLayer.addSublayer(videoLayer)
            outputLayer.addSublayer(overlayLayer)
            
            // add the canvas layer to video composition
            videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: outputLayer)
            
            guard let export = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
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
    
}

extension PhotoEditorViewController {
    
    private func videoCompositionLayerInstruction(compositionTrack: AVCompositionTrack, assetTrack: AVAssetTrack, renderSize: CGSize, topOffset: CGFloat) -> AVMutableVideoCompositionLayerInstruction {
        
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
        
        let assetInfo = orientation(from: assetTrack.preferredTransform)
        
        var scaleToFitRatio = renderSize.width / assetTrack.naturalSize.width
        if assetInfo.isPortrait {
            scaleToFitRatio = renderSize.width / assetTrack.naturalSize.height
            let scale = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
            instruction.setTransform(assetTrack.preferredTransform.concatenating(scale), at: .zero)
        } else {
            let scale = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
            let translationY = (renderSize.width / 2) + topOffset
            let translation = CGAffineTransform(translationX: 0, y: translationY)
            var concat = assetTrack.preferredTransform.concatenating(scale).concatenating(translation)
            if assetInfo.orientation == .down {
                let fixUpsideDown = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                let windowBounds = renderSize
                let translationY = assetTrack.naturalSize.height + windowBounds.height
                let translation = CGAffineTransform(translationX: assetTrack.naturalSize.width, y: translationY)
                concat = fixUpsideDown.concatenating(translation).concatenating(scale)
            }
            instruction.setTransform(concat, at: .zero)
        }
        
        return instruction
        
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
    
    private func add(image: UIImage, to layer: CALayer) {
        let imageLayer = CALayer()
        imageLayer.frame = layer.frame
        imageLayer.contents = image.cgImage
        imageLayer.contentsGravity = .resizeAspectFill  // check .resizeAspect too
        layer.addSublayer(imageLayer)
    }
    
}
