//
//  PhotoEditor+VideoExporter.swift
//  iOSPhotoEditor
//
//  Created by Mufakkharul Islam Nayem on 8/8/20.
//

import AVFoundation

extension MediaEditorViewController {
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
                let startTime = trimmerView.startTime ?? .zero
                let endTime = trimmerView.endTime ?? asset.duration
                let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
                try compositionTrack.insertTimeRange(timeRange, of: assetTrack, at: .zero)
                
                // if audio isn't muted in the editor, add audio track from the asset
                if !isAudioMuted, let audioAssetTrack = asset.tracks(withMediaType: .audio).first,
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
            
            // Composition Instructions
            let compositionInstruction = AVMutableVideoCompositionInstruction()
            compositionInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
            
            // Set up the layer instruction
            let layerInstruction = videoCompositionLayerInstruction(compositionTrack: compositionTrack, assetTrack: assetTrack, renderSize: renderSize)
            
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
            
            guard let export = AVAssetExportSession(asset: mixComposition, presetName: videoQuality.exportPreset)
                else {
                    print("Cannot create export session.")
                    onComplete(nil)
                    return
            }
            
            let videoName = UUID().uuidString
            let exportURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(videoName)
                .appendingPathExtension("mp4")
            
            export.videoComposition = videoComposition
            export.outputFileType = .mp4
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

extension MediaEditorViewController {
    
    private func videoCompositionLayerInstruction(compositionTrack: AVCompositionTrack, assetTrack: AVAssetTrack, renderSize: CGSize) -> AVMutableVideoCompositionLayerInstruction {
        
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
        
        let assetInfo = orientation(from: assetTrack)
        
        if assetInfo.isPortrait {
            let scaleToFitRatio = renderSize.width / assetTrack.naturalSize.height
            let scale = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
            
            // applying scale spoils the vertical position for a portrait video asset captured with front camera but not rear camera
            // the key to fix this is to negate the delta y in the transformation matrix of `scale` applied to the asset
            // hence the `scaledTransformVerticalTranslation` is used below
            let scaledTransform = assetTrack.preferredTransform.concatenating(scale)
            let scaledTransformVerticalTranslation = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: -scaledTransform.ty)
            
            let concat = assetTrack.preferredTransform.concatenating(scale).concatenating(scaledTransformVerticalTranslation)
            instruction.setTransform(concat, at: .zero)
        } else {
            let scaleToFitRatio = renderSize.width / assetTrack.naturalSize.width
            let scale = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
            let translationY = (renderSize.height / 2) - ((assetTrack.naturalSize.height * scaleToFitRatio) / 2)
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
    
    private func orientation(from assetTrack: AVAssetTrack) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        
        var assetOrientation = UIImage.Orientation.up
        
        let transform = assetTrack.preferredTransform
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            assetOrientation = .right
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            assetOrientation = .left
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            assetOrientation = .up
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            assetOrientation = .down
        }
        
        // this formula is from: https://stackoverflow.com/a/39596966/3687801
        let isPortrait: Bool
        switch (transform.tx, transform.ty) {
        case (0, 0):
            isPortrait = false
        case (assetTrack.naturalSize.width, assetTrack.naturalSize.height):
            isPortrait = false
        case (0, assetTrack.naturalSize.width):
            isPortrait = true
        default:
            isPortrait = true
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
