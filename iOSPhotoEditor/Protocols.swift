//
//  Protocols.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 6/15/17.
//
//

import Foundation
import UIKit
/**
 - doneEditing
 - canceledEditing
 */

public protocol MediaEditorDelegate {
    /**
     - Parameter image: edited Image
     */
    func mediaEditorViewController(_ controller: MediaEditorViewController, doneEditing image: UIImage)
    
    /// Method to be executed when video editing is completed.
    /// - Parameter url: The local URL where the video is saved temporarily. 
    func mediaEditorViewController(_ controller: MediaEditorViewController, doneEditingVideo url: URL)
    /**
     StickersViewController did Disappear
     */
    func mediaEditorViewControllerCanceledEditing(_ controller: MediaEditorViewController)
}


/**
 - didSelectView
 - didSelectImage
 - stickersViewDidDisappear
 */
protocol StickersViewControllerDelegate {
    /**
     - Parameter view: selected view from StickersViewController
     */
    func didSelectView(view: UIView)
    /**
     - Parameter image: selected Image from StickersViewController
     */
    func didSelectImage(image: UIImage)
    /**
     StickersViewController did Disappear
     */
    func stickersViewDidDisappear()
}

/**
 - didSelectColor
 */
protocol ColorDelegate {
    func didSelectColor(color: UIColor)
}
