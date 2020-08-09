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

extension ViewController: PhotoEditorDelegate {
    
    func doneEditing(image: UIImage) {
        imageView.image = image
    }
    
    func doneEditingVideo(url: URL) {
        // play video
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        videoPlayerView.player = queuePlayer
        
        queuePlayer.play()
    }
    
    func canceledEditing() {
        print("Canceled")
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true, completion: nil)
        
        if let image = info[.originalImage] as? UIImage {
            let photoEditor = PhotoEditorViewController.makeForImage(image)
            photoEditor.photoEditorDelegate = self
            //Colors for drawing and Text, If not set default values will be used
            //photoEditor.colors = [.red, .blue, .green]
            
            //Stickers that the user will choose from to add on the image
            for i in 0...10 {
                photoEditor.stickers.append(UIImage(named: i.description )!)
            }
            
            //To hide controls - array of enum Control
            //photoEditor.hiddenControls = [.crop, .draw, .share]
            photoEditor.modalPresentationStyle = .fullScreen
            present(photoEditor, animated: true, completion: nil)
        } else if let videoURL = info[.mediaURL] as? URL {
            let editor = PhotoEditorViewController.makeForVideo(videoURL)
            editor.photoEditorDelegate = self
            editor.modalPresentationStyle = .fullScreen
            present(editor, animated: true, completion: nil)
        }
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}
