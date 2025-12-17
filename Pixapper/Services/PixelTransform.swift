//
//  PixelTransform.swift
//  Pixapper
//
//  픽셀 변환 유틸리티
//  SelectionTool에서 추출한 순수 함수들 (사이드 이펙트 없음)
//

import SwiftUI

struct PixelTransform {
    // MARK: - Scaling

    /// 픽셀 배열을 지정한 크기로 스케일링 (nearest-neighbor 알고리즘)
    static func scale(_ pixels: [[Color?]], toWidth newWidth: Int, toHeight newHeight: Int) -> [[Color?]] {
        let oldHeight = pixels.count
        let oldWidth = pixels[0].count

        var scaled: [[Color?]] = []

        for y in 0..<newHeight {
            var row: [Color?] = []
            let srcY = Int(Double(y) * Double(oldHeight) / Double(newHeight))

            for x in 0..<newWidth {
                let srcX = Int(Double(x) * Double(oldWidth) / Double(newWidth))
                row.append(pixels[srcY][srcX])
            }
            scaled.append(row)
        }

        return scaled
    }

    // MARK: - Rotation (90도 단위)

    /// 픽셀 배열을 시계 방향으로 90도 회전
    static func rotate90CW(_ pixels: [[Color?]]) -> [[Color?]] {
        let oldHeight = pixels.count
        let oldWidth = pixels[0].count
        var rotated: [[Color?]] = Array(repeating: Array(repeating: nil, count: oldHeight), count: oldWidth)

        for y in 0..<oldHeight {
            for x in 0..<oldWidth {
                rotated[x][oldHeight - 1 - y] = pixels[y][x]
            }
        }

        return rotated
    }

    /// 픽셀 배열을 반시계 방향으로 90도 회전
    static func rotate90CCW(_ pixels: [[Color?]]) -> [[Color?]] {
        let oldHeight = pixels.count
        let oldWidth = pixels[0].count
        var rotated: [[Color?]] = Array(repeating: Array(repeating: nil, count: oldHeight), count: oldWidth)

        for y in 0..<oldHeight {
            for x in 0..<oldWidth {
                rotated[oldWidth - 1 - x][y] = pixels[y][x]
            }
        }

        return rotated
    }

    /// 픽셀 배열을 180도 회전
    static func rotate180(_ pixels: [[Color?]]) -> [[Color?]] {
        let height = pixels.count
        let width = pixels[0].count
        var rotated: [[Color?]] = Array(repeating: Array(repeating: nil, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                rotated[height - 1 - y][width - 1 - x] = pixels[y][x]
            }
        }

        return rotated
    }

    // MARK: - Rotation (임의 각도)

    /// 픽셀 배열을 임의 각도로 회전 (라디안 단위)
    /// 회전 후 바운딩 박스에 맞게 자동 크기 조정
    static func rotateByAngle(_ pixels: [[Color?]], angle: Double) -> [[Color?]] {
        let oldHeight = pixels.count
        let oldWidth = pixels.isEmpty ? 0 : pixels[0].count
        let pivotX = Double(oldWidth) / 2.0
        let pivotY = Double(oldHeight) / 2.0

        guard !pixels.isEmpty else { return [] }

        let corners = [
            (0.0, 0.0),
            (Double(oldWidth), 0.0),
            (0.0, Double(oldHeight)),
            (Double(oldWidth), Double(oldHeight))
        ]

        var minX = Double.infinity
        var maxX = -Double.infinity
        var minY = Double.infinity
        var maxY = -Double.infinity

        for (x, y) in corners {
            let dx = x - pivotX
            let dy = y - pivotY
            let rotatedX = dx * cos(angle) - dy * sin(angle)
            let rotatedY = dx * sin(angle) + dy * cos(angle)

            minX = min(minX, rotatedX)
            maxX = max(maxX, rotatedX)
            minY = min(minY, rotatedY)
            maxY = max(maxY, rotatedY)
        }

        let newWidth = Int(ceil(maxX - minX))
        let newHeight = Int(ceil(maxY - minY))

        var rotated: [[Color?]] = Array(repeating: Array(repeating: nil, count: newWidth), count: newHeight)

        for y in 0..<newHeight {
            for x in 0..<newWidth {
                let dx = Double(x) + minX
                let dy = Double(y) + minY

                let srcX = dx * cos(-angle) - dy * sin(-angle) + pivotX
                let srcY = dx * sin(-angle) + dy * cos(-angle) + pivotY

                let srcXInt = Int(round(srcX))
                let srcYInt = Int(round(srcY))

                if srcXInt >= 0 && srcXInt < oldWidth && srcYInt >= 0 && srcYInt < oldHeight {
                    rotated[y][x] = pixels[srcYInt][srcXInt]
                }
            }
        }

        return rotated
    }

    /// 회전 후 바운딩 박스 크기 계산
    static func calculateRotatedBoundingBox(width: CGFloat, height: CGFloat, angle: Double) -> CGSize {
        if abs(angle) < 0.001 {
            return CGSize(width: width, height: height)
        }

        let corners = [
            (0.0, 0.0),
            (Double(width), 0.0),
            (0.0, Double(height)),
            (Double(width), Double(height))
        ]

        let pivotX = Double(width) / 2.0
        let pivotY = Double(height) / 2.0

        var minX = Double.infinity
        var maxX = -Double.infinity
        var minY = Double.infinity
        var maxY = -Double.infinity

        for (x, y) in corners {
            let dx = x - pivotX
            let dy = y - pivotY
            let rotatedX = dx * cos(angle) - dy * sin(angle)
            let rotatedY = dx * sin(angle) + dy * cos(angle)

            minX = min(minX, rotatedX)
            maxX = max(maxX, rotatedX)
            minY = min(minY, rotatedY)
            maxY = max(maxY, rotatedY)
        }

        return CGSize(width: maxX - minX, height: maxY - minY)
    }

    // MARK: - Flip

    /// 픽셀 배열을 수평으로 뒤집기
    static func flipHorizontal(_ pixels: [[Color?]]) -> [[Color?]] {
        let height = pixels.count
        let width = pixels[0].count
        var flipped: [[Color?]] = Array(repeating: Array(repeating: nil, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                flipped[y][width - 1 - x] = pixels[y][x]
            }
        }

        return flipped
    }

    /// 픽셀 배열을 수직으로 뒤집기
    static func flipVertical(_ pixels: [[Color?]]) -> [[Color?]] {
        let height = pixels.count
        let width = pixels[0].count
        var flipped: [[Color?]] = Array(repeating: Array(repeating: nil, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                flipped[height - 1 - y][x] = pixels[y][x]
            }
        }

        return flipped
    }

    // MARK: - Crop

    /// 픽셀 배열을 내용물 기준으로 크롭 (nil이 아닌 픽셀만 포함)
    /// Returns: (크롭된 픽셀 배열, 크롭 오프셋)
    static func cropToContent(_ pixels: [[Color?]]) -> ([[Color?]], offset: (x: Int, y: Int)) {
        guard !pixels.isEmpty, !pixels[0].isEmpty else {
            return (pixels, (0, 0))
        }

        var minX = pixels[0].count
        var minY = pixels.count
        var maxX = -1
        var maxY = -1

        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                if pixels[y][x] != nil {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        if maxX < 0 {
            return ([[nil]], (0, 0))
        }

        let cropWidth = maxX - minX + 1
        let cropHeight = maxY - minY + 1
        var cropped: [[Color?]] = Array(repeating: Array(repeating: nil, count: cropWidth), count: cropHeight)

        for y in 0..<cropHeight {
            for x in 0..<cropWidth {
                cropped[y][x] = pixels[minY + y][minX + x]
            }
        }

        return (cropped, (minX, minY))
    }

    // MARK: - Mask Operations

    /// 마스크를 픽셀에 적용 (마스크 밖 픽셀을 nil로 변경)
    static func applyMask(to pixels: inout [[Color?]], mask: [[Bool]]) {
        guard !pixels.isEmpty && !pixels[0].isEmpty else { return }
        guard !mask.isEmpty && !mask[0].isEmpty else { return }

        let height = min(pixels.count, mask.count)
        let width = min(pixels[0].count, mask[0].count)

        for y in 0..<height {
            for x in 0..<width {
                if !mask[y][x] {
                    pixels[y][x] = nil
                }
            }
        }
    }

    /// 픽셀에서 마스크 생성 (nil이 아닌 부분을 true로)
    static func createMask(from pixels: [[Color?]]) -> [[Bool]] {
        guard !pixels.isEmpty && !pixels[0].isEmpty else { return [] }

        let height = pixels.count
        let width = pixels[0].count

        var mask: [[Bool]] = Array(repeating: Array(repeating: false, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                mask[y][x] = (pixels[y][x] != nil)
            }
        }

        return mask
    }
}
