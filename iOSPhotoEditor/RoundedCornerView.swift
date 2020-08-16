//
//  RoundedCornerView.swift
//  iOSPhotoEditor
//
//  Created by Mufakkharul Islam Nayem on 17/8/20.
//

import UIKit

@IBDesignable class RoundedCornerView: UIView {
    
    private var _cornerRadius: CGFloat = 0
    
    @IBInspectable var cornerRadius: CGFloat {
        set {
            _cornerRadius = newValue
            makeRound()
        }
        get {
            return self._cornerRadius
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
        if self.cornerRadius > 0 {
            self.clipsToBounds = true
        }
        self.layer.cornerRadius = self.cornerRadius
    }
    
    override func layoutSubviews() {
        makeRound()
    }
    
}
