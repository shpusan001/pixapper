//
//  FreeformSelector.swift
//  Pixapper
//
//  자유형 선택 경로 처리 담당
//  SelectionTool에서 추출한 Freeform 로직
//

import SwiftUI

@MainActor
class FreeformSelector {
    // MARK: - Public Methods

    /// Freeform 경로를 업데이트 (드래그 중)
    /// - Parameters:
    ///   - path: 현재까지의 경로 (inout)
    ///   - lastPoint: 마지막 그린 점 (inout)
    ///   - currentX: 현재 X 좌표
    ///   - currentY: 현재 Y 좌표
    ///   - canvasWidth: 캔버스 너비
    ///   - canvasHeight: 캔버스 높이
    func updatePath(
        path: inout [(x: Int, y: Int)],
        lastPoint: inout (x: Int, y: Int)?,
        currentX: Int,
        currentY: Int,
        canvasWidth: Int,
        canvasHeight: Int
    ) {
        guard currentX >= 0 && currentX < canvasWidth &&
              currentY >= 0 && currentY < canvasHeight else { return }

        if let last = lastPoint {
            if last.x == currentX && last.y == currentY { return }

            let points = bresenhamLine(x0: last.x, y0: last.y, x1: currentX, y1: currentY)
            for i in 1..<points.count {
                let point = points[i]
                if point.x >= 0 && point.x < canvasWidth &&
                   point.y >= 0 && point.y < canvasHeight {
                    path.append(point)
                }
            }
        } else {
            path.append((currentX, currentY))
        }

        lastPoint = (currentX, currentY)
    }

    /// Freeform 경로 닫기 (시작점과 끝점을 직선으로 연결)
    /// - Parameters:
    ///   - path: 닫을 경로 (inout)
    ///   - canvasWidth: 캔버스 너비
    ///   - canvasHeight: 캔버스 높이
    func closePath(
        path: inout [(x: Int, y: Int)],
        canvasWidth: Int,
        canvasHeight: Int
    ) {
        guard path.count >= 2 else { return }

        let first = path.first!
        let last = path.last!

        let distance = abs(first.x - last.x) + abs(first.y - last.y)
        if distance <= 2 { return }

        let closingLine = bresenhamLine(x0: last.x, y0: last.y, x1: first.x, y1: first.y)
        for i in 1..<closingLine.count {
            let point = closingLine[i]
            if point.x >= 0 && point.x < canvasWidth &&
               point.y >= 0 && point.y < canvasHeight {
                path.append(point)
            }
        }
    }

    /// 경로로부터 바운딩 박스 계산
    /// - Parameter path: 경로
    /// - Returns: 경로의 바운딩 박스
    func calculateBoundingBox(from path: [(x: Int, y: Int)]) -> CGRect? {
        guard path.count > 0 else { return nil }

        var minX = Int.max
        var maxX = Int.min
        var minY = Int.max
        var maxY = Int.min

        for point in path {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    }

    /// Scanline Fill 알고리즘으로 경로 내부를 마스크로 채우기
    /// Even-Odd Rule 사용 (Photoshop/Aseprite 표준)
    /// - Parameters:
    ///   - mask: 채울 마스크 (inout)
    ///   - path: 경로 (절대 좌표)
    ///   - startX: 마스크 시작 X (절대 좌표)
    ///   - startY: 마스크 시작 Y (절대 좌표)
    func fillInterior(
        mask: inout [[Bool]],
        path: [(x: Int, y: Int)],
        startX: Int,
        startY: Int
    ) {
        let width = mask[0].count
        let height = mask.count

        guard path.count >= 3 else { return }

        var localPath: [(x: Int, y: Int)] = []
        for point in path {
            localPath.append((x: point.x - startX, y: point.y - startY))
        }

        for y in 0..<height {
            var intersections: [Int] = []

            for i in 0..<localPath.count {
                let p1 = localPath[i]
                let p2 = localPath[(i + 1) % localPath.count]

                let minY = min(p1.y, p2.y)
                let maxY = max(p1.y, p2.y)

                if y >= minY && y < maxY {
                    let dx = p2.x - p1.x
                    let dy = p2.y - p1.y

                    if dy != 0 {
                        let x = p1.x + (y - p1.y) * dx / dy
                        intersections.append(x)
                    }
                }
            }

            intersections.sort()

            for i in stride(from: 0, to: intersections.count - 1, by: 2) {
                let x1 = max(0, intersections[i])
                let x2 = min(width - 1, intersections[i + 1])

                for x in x1...x2 {
                    mask[y][x] = true
                }
            }
        }
    }

    // MARK: - Private Methods

    /// 브레센햄 직선 알고리즘
    private func bresenhamLine(x0: Int, y0: Int, x1: Int, y1: Int) -> [(x: Int, y: Int)] {
        var points: [(x: Int, y: Int)] = []

        let dx = abs(x1 - x0)
        let dy = abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx - dy
        var x = x0
        var y = y0

        while true {
            points.append((x, y))

            if x == x1 && y == y1 {
                break
            }

            let e2 = 2 * err
            if e2 > -dy {
                err -= dy
                x += sx
            }
            if e2 < dx {
                err += dx
                y += sy
            }
        }

        return points
    }
}
