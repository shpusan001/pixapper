//
//  Layer.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

enum BlendMode: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case multiply = "Multiply"
    case screen = "Screen"

    var id: String { rawValue }
}

struct Layer: Identifiable {
    let id = UUID()
    var name: String
    var pixels: [[Color?]]
    var isVisible: Bool = true
    var opacity: Double = 1.0
    var blendMode: BlendMode = .normal

    init(name: String, width: Int, height: Int) {
        self.name = name
        self.pixels = Array(repeating: Array(repeating: nil, count: width), count: height)
    }

    func getPixel(x: Int, y: Int) -> Color? {
        guard y >= 0 && y < pixels.count && x >= 0 && x < pixels[0].count else {
            return nil
        }
        return pixels[y][x]
    }

    mutating func setPixel(x: Int, y: Int, color: Color?) {
        guard y >= 0 && y < pixels.count && x >= 0 && x < pixels[0].count else {
            return
        }
        pixels[y][x] = color
    }
}
