//
//  PixelCanvas.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import Foundation

struct PixelCanvas {
    var width: Int
    var height: Int
    var layers: [Layer]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.layers = [Layer(name: "Layer 1", width: width, height: height)]
    }
}
