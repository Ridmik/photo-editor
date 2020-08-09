//
//  UIImageView+Image.swift
//  iOSPhotoEditor
//
//  Created by Mufakkharul Islam Nayem on 9/8/20.
//

import Foundation

extension UIImageView {
    
    var layerImage: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
    
}
