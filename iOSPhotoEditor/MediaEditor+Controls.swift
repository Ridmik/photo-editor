//
//  PhotoEditor+Controls.swift
//  Pods
//
//  Created by Mohamed Hamed on 6/16/17.
//
//

import Foundation
import UIKit
import Photos

// MARK: - Control
public enum Control {
    case crop
    case trim
    case sticker
    case draw
    case marker
    case volume
    case text
    case save
    case share
    case clear
}

public enum ContinueButtonStyle {
    case icon
    case imageWithText(UIImage, String)
}

extension MediaEditorViewController {

     //MARK: Top Toolbar
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        mediaEditorDelegate?.canceledEditing()
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func cropButtonTapped(_ sender: UIButton) {
        if case .photo(let image) = self.media {
            let controller = CropViewController()
            controller.delegate = self
            controller.image = image
            let navController = UINavigationController(rootViewController: controller)
            present(navController, animated: true, completion: nil)
        }
    }
    
    @IBAction func trimButtonTapped(_ sender: UIButton) {
        if case .video(let url) = self.media {
            trimmerContainerView.isHidden = false
            doneButton.isHidden = false
            hideToolbar(hide: true)
            let asset = AVAsset(url: url)
            /* this is a nifty trick of setting trimmer view max duration to
             the asset duration by subtracting a negligible millisecond so that
             the queue player playback finish doesn't force the preview player to be played from
             the beginning of the video asset instead of trimmer start time
            */
            trimmerView.maxDuration = asset.duration.seconds - 0.05
            trimmerView.asset = asset
            trimDurationLabel.text = trimmingDuration
        }
    }

    @IBAction func stickersButtonTapped(_ sender: Any) {
        addStickersViewController()
    }

    @IBAction func drawButtonTapped(_ sender: Any) {
        isDrawing = true
        canvasImageView.isUserInteractionEnabled = false
        doneButton.isHidden = false
        colorPickerView.isHidden = false
        hideToolbar(hide: true)
    }
    
    @IBAction func markerButtonTapped(_ sender: UIButton) {
        drawColor = .white
        isDrawing = true
        canvasImageView.isUserInteractionEnabled = false
        doneButton.isHidden = false
        hideToolbar(hide: true)
    }
    
    @IBAction func volumeButtonTapped(_ sender: UIButton) {
        isAudioMuted.toggle()
    }

    @IBAction func textButtonTapped(_ sender: Any) {
        isTyping = true
        let textView = UITextView(frame: CGRect(x: 0, y: canvasImageView.center.y,
                                                width: UIScreen.main.bounds.width, height: 30))
        
        textView.textAlignment = .center
        textView.font = UIFont(name: "Helvetica", size: 30)
        textView.textColor = textColor
        textView.layer.shadowColor = UIColor.black.cgColor
        textView.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
        textView.layer.shadowOpacity = 0.2
        textView.layer.shadowRadius = 1.0
        textView.layer.backgroundColor = UIColor.clear.cgColor
        textView.autocorrectionType = .no
        textView.isScrollEnabled = false
        textView.delegate = self
        self.canvasImageView.addSubview(textView)
        addGestures(view: textView)
        textView.becomeFirstResponder()
    }    
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        view.endEditing(true)
        doneButton.isHidden = true
        colorPickerView.isHidden = true
        canvasImageView.isUserInteractionEnabled = true
        hideToolbar(hide: false)
        isDrawing = false
        // reset drawing color
        drawColor = drawColorInitial
        trimmerContainerView.isHidden = true
    }
    
    //MARK: Bottom Toolbar
    
    @IBAction func saveButtonTapped(_ sender: AnyObject) {
        switch self.media {
        case .photo(_):
            let image = canvasView.toImage()
            let savePhotoToPhotos = {
                let changes: (() -> Void) = {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                PHPhotoLibrary.shared().performChanges(changes) { saved, error in
                    DispatchQueue.main.async {
                        self.photoLibraryChangePerformed(media: self.media, saved: saved, error: error)
                    }
                }
            }
            
            self.performWithCheckingPhotoLibraryAuthorization(performBlock: savePhotoToPhotos)
            
        case .video(_):
            showLoader()
            exportAsVideo { [weak self] videoURL in
                self?.hideLoader()
                guard let self = self, let videoURL = videoURL else { return }
                let saveVideoToPhotos = {
                    let changes: (() -> Void) = { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL) }
                    PHPhotoLibrary.shared().performChanges(changes) { saved, error in
                        DispatchQueue.main.async {
                            self.photoLibraryChangePerformed(media: self.media, saved: saved, error: error)
                        }
                    }
                }
                
                self.performWithCheckingPhotoLibraryAuthorization(performBlock: saveVideoToPhotos)
                
            }
        case .none:
            break
        }
    }
    
    @IBAction func shareButtonTapped(_ sender: UIButton) {
        let activity = UIActivityViewController(activityItems: [canvasView.toImage()], applicationActivities: nil)
        present(activity, animated: true, completion: nil)
        
    }
    
    @IBAction func clearButtonTapped(_ sender: AnyObject) {
        //clear drawing
        canvasImageView.image = nil
        //clear stickers and textviews
        for subview in canvasImageView.subviews {
            subview.removeFromSuperview()
        }
    }
    
    @IBAction func continueButtonPressed(_ sender: Any) {
        switch self.media {
        case .photo(_):
            let img = self.canvasView.toImage()
            mediaEditorDelegate?.doneEditing(image: img)
            self.dismiss(animated: true, completion: nil)
        case .video(_):
            showLoader()
            exportAsVideo { [weak self] url in
                self?.hideLoader()
                if let url = url {
                    self?.mediaEditorDelegate?.doneEditingVideo(url: url)
                }
                self?.dismiss(animated: true, completion: nil)
            }
        case .none:
            break
        }
    }

    // MARK: Helper methods
    private func performWithCheckingPhotoLibraryAuthorization(performBlock: @escaping (() -> Void)) {
        // Ensure permission to access Photo Library
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized:
                    performBlock()
                default:
                    DispatchQueue.main.async {
                        // show an alert that user needs to give permission for photo access
                        let alert = UIAlertController(title: "Photos access needed.", message: "To continue to save to photos, you need to allow read & write access. Continue?", preferredStyle: .alert)
                        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                        let settingsAction = UIAlertAction(title: "Settings", style: .default) { _ in
                            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(settingsURL)
                        }
                        alert.addAction(cancelAction)
                        alert.addAction(settingsAction)
                        self.present(alert, animated: true)
                    }
                }
            }
        } else {
            performBlock()
        }
    }
    
    private func photoLibraryChangePerformed(media: Media, saved: Bool, error: Error?) {
        let success = saved && (error == nil)
        let title = success ? "Success" : "Error"
        let mediaString: String
        switch media {
        case .photo(_):
            mediaString = "Photo"
        case .video(_):
            mediaString = "Video"
        }
        let message = success ? "\(mediaString) saved" : "Failed to save \(mediaString)"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func hideControls() {
        for control in (hiddenControls + defaultHiddenControls) {
            switch control {
            case .clear:
                if let circularView = clearButton.superview as? CircularView {
                    circularView.isHidden = true
                } else {
                    clearButton.isHidden = true
                }
            case .crop:
                if let circularView = cropButton.superview as? CircularView {
                    circularView.isHidden = true
                } else {
                    cropButton.isHidden = true
                }
            case .draw:
                if let circularView = drawButton.superview as? CircularView {
                    circularView.isHidden = true
                } else {
                    drawButton.isHidden = true
                }
            case .marker:
                if let circularView = markerButton.superview as? CircularView {
                    circularView.isHidden = true
                } else {
                    markerButton.isHidden = true
                }
            case .save:
                if let circularView = saveButton.superview as? CircularView {
                    circularView.isHidden = true
                } else {
                    saveButton.isHidden = true
                }
            case .share:
                if let circularView = shareButton.superview as? CircularView {
                    circularView.isHidden = true
                } else {
                    shareButton.isHidden = true
                }
            case .sticker:
                if let circularView = stickerButton.superview as? CircularView {
                    circularView.isHidden = true
                } else {
                    stickerButton.isHidden = true
                }
            case .text:
                if let circularView = textButton.superview as? CircularView {
                    circularView.isHidden = true
                } else {
                    textButton.isHidden = true
                }
            case .trim:
                if let circularView = trimButton.superview as? CircularView {
                    circularView.isHidden = true
                } else {
                    trimButton.isHidden = true
                }
            case .volume:
                if let circularView = volumeButton.superview as? CircularView {
                    circularView.isHidden = true
                } else {
                    volumeButton.isHidden = true
                }
            }
        }
    }
    
    func setupContinueButton() {
        switch continueButtonStyle {
        case .imageWithText(let image, let text):
            // hide the icon button
            if let circularView = continueIconButton.superview as? CircularView {
                circularView.isHidden = true
            } else {
                continueIconButton.isHidden = true
            }
            // setup custom button view
            continueButtonImageView.image = image
            continueButtonLabel.text = text
            // add gesture
            let tap = UITapGestureRecognizer(target: self, action: #selector(continueButtonPressed(_:)))
            continueImageLabelButtonView.addGestureRecognizer(tap)
        default:
            // hide custom button view
            continueImageLabelButtonView.isHidden = true
        }
    }
    
    func showLoader() {
        activityIndicatorContainerView.isHidden = false
    }
    
    func hideLoader() {
        activityIndicatorContainerView.isHidden = true
    }
    
}
