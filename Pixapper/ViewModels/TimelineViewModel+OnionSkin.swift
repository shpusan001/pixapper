//
//  TimelineViewModel+OnionSkin.swift
//  Pixapper
//
//  Created by Claude on 2025-12-11.
//

import SwiftUI

// MARK: - Onion Skin Extension
extension TimelineViewModel {

    func getOnionSkinFrames() -> [(frameIndex: Int, tint: Color, opacity: Double)] {
        var result: [(frameIndex: Int, tint: Color, opacity: Double)] = []

        if !settings.onionSkinEnabled {
            return result
        }

        // Previous frames (red tint)
        for i in 1...settings.onionSkinPrevFrames {
            let frameIndex = currentFrameIndex - i
            if frameIndex >= 0 && frameIndex < totalFrames {
                let opacity = settings.onionSkinOpacity / Double(i)
                result.append((frameIndex, .red, opacity))
            }
        }

        // Next frames (blue tint)
        for i in 1...settings.onionSkinNextFrames {
            let frameIndex = currentFrameIndex + i
            if frameIndex >= 0 && frameIndex < totalFrames {
                let opacity = settings.onionSkinOpacity / Double(i)
                result.append((frameIndex, .blue, opacity))
            }
        }

        return result
    }
}
