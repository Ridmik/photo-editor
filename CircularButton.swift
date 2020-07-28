//
//  CircularButton.swift
//  iOSPhotoEditor
//
//  Created by Mufakkharul Islam Nayem on 28/7/20.
//

import UIKit

@IBDesignable class CircularButton: UIButton {
    
    private var _round = false
    
    @IBInspectable var circular: Bool {
        set {
            _round = newValue
            makeRound()
        }
        get {
            return self._round
        }
    }
    
    override internal var frame: CGRect {
        set {
            super.frame = newValue
            makeRound()
        }
        get {
            return super.frame
        }
        
    }
    
    private func makeRound() {
        if self.circular == true {
            self.clipsToBounds = true
            self.layer.cornerRadius = (self.frame.width + self.frame.height) / 4
        } else {
            self.layer.cornerRadius = 0
        }
    }
    
    override func layoutSubviews() {
        makeRound()
    }
    
}
