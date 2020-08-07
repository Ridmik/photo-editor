//
//  VideoPlayer.swift
//  iOSPhotoEditor
//
//  Created by Mufakkharul Islam Nayem on 8/8/20.
//

import AVFoundation

class VideoPlayer: UIView {
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    var player: AVPlayer! {
        set {
            playerLayer.player = newValue
        }
        get {
            return playerLayer.player
        }
    }
    
}
