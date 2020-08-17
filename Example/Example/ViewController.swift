//
//  ViewController.swift
//  editorTest
//
//  Created by Mohamed Hamed on 5/4/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit
import iOSPhotoEditor
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var videoPlayerView: VideoPlayer!
    
    private let queuePlayer = AVQueuePlayer()
    private var playerLooper: AVPlayerLooper?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.isHidden = true
        videoPlayerView.isHidden = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        queuePlayer.pause()
    }
    
    @IBAction func pickMediaButtonTapped(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary)!
        present(picker, animated: true, completion: nil)
    }
}

extension ViewController: MediaEditorDelegate {
    
    func doneEditing(image: UIImage) {
        imageView.image = image
        imageView.isHidden = false
        videoPlayerView.isHidden = true
    }
    
    func doneEditingVideo(url: URL) {
        // play video
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        videoPlayerView.player = queuePlayer
        
        queuePlayer.play()
        imageView.isHidden = true
        videoPlayerView.isHidden = false
    }
    
    func canceledEditing() {
        print("Canceled")
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true, completion: nil)
        
        if let image = info[.originalImage] as? UIImage {
            let editor = MediaEditorViewController.makeForImage(image)
            editor.mediaEditorDelegate = self
            //Colors for drawing and Text, If not set default values will be used
            //editor.colors = [.red, .blue, .green]
            
            //Stickers that the user will choose from to add on the image
            for i in 0...10 {
                editor.stickers.append(UIImage(named: i.description )!)
            }
            
            //To hide controls - array of enum Control
            //photoEditor.hiddenControls = [.crop, .draw, .share]
            editor.modalPresentationStyle = .fullScreen
            present(editor, animated: true, completion: nil)
        } else if let videoURL = info[.mediaURL] as? URL {
            let editor = MediaEditorViewController.makeForVideo(videoURL)
            editor.mediaEditorDelegate = self
            editor.modalPresentationStyle = .fullScreen
            present(editor, animated: true, completion: nil)
        }
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}
