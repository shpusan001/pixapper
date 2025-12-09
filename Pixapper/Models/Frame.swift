//
//  Frame.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import Foundation

struct Frame: Identifiable {
    let id = UUID()
    var layers: [Layer]

    init(width: Int, height: Int) {
        self.layers = [Layer(name: "Layer 1", width: width, height: height)]
    }

    init(layers: [Layer]) {
        self.layers = layers
    }
}

struct AnimationSettings {
    var fps: Int = 12
    var playbackSpeed: Double = 1.0
    var isLooping: Bool = true
    var onionSkinEnabled: Bool = false
    var onionSkinPrevFrames: Int = 1
    var onionSkinNextFrames: Int = 1
    var onionSkinOpacity: Double = 0.3

    var effectiveFPS: Double {
        Double(fps) * playbackSpeed
    }

    var frameDuration: Double {
        1.0 / effectiveFPS
    }
}
