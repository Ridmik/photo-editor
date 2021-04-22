//
//  UIImage+Size.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 5/2/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit

public extension UIImage {
    
    enum Limit {
        case width(CGFloat)
        case height(CGFloat)
    }
    
    /**
     Suitable size for specific height or width to keep same image ratio
     */
    func suitableSize(limit: Limit)-> CGSize {
        
        switch limit {
        case .width(let width):
            let height = (width / self.size.width) * self.size.height
            return CGSize(width: width, height: min(height, UIScreen.main.bounds.height))
        case .height(let height):
            let width = (height / self.size.height) * self.size.width
            return CGSize(width: min(width, UIScreen.main.bounds.width), height: height)
        }
        
    }
}
