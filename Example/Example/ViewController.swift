//
//  ViewController.swift
//  editorTest
//
//  Created by Mohamed Hamed on 5/4/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit
import iOSPhotoEditor

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func pickImageButtonTapped(_ sender: Any) {
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
    
    func canceledEditing() {
        print("Canceled")
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true, completion: nil)
        
        if let image = info[.originalImage] as? UIImage {
            let photoEditor = PhotoEditorViewController(nibName:"PhotoEditorViewController",bundle: Bundle(for: PhotoEditorViewController.self))
            photoEditor.photoEditorDelegate = self
            photoEditor.image = image
            //Colors for drawing and Text, If not set default values will be used
            //photoEditor.colors = [.red, .blue, .green]
            
            //Stickers that the user will choose from to add on the image
            for i in 0...10 {
                photoEditor.stickers.append(UIImage(named: i.description )!)
            }
            
            //To hide controls - array of enum Control
            //photoEditor.hiddenControls = [.crop, .draw, .share]
            photoEditor.modalPresentationStyle = UIModalPresentationStyle.currentContext //or .overFullScreen for transparency
            present(photoEditor, animated: true, completion: nil)
        } else if let videoURL = info[.mediaURL] as? URL {
            print("Handle video located at: \(videoURL)")
        }
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}
