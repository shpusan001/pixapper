//
//  GradientLibrary.swift
//  Pixapper
//
//  Created by Claude on 2025-12-19.
//

import Foundation

/// 그라디언트 타입
enum GradientType: String, Codable {
    case linear     // 선형 그라디언트
    case radial     // 방사형 그라디언트
    case angular    // 각도 그라디언트 (원형)
}

/// 그라디언트 정지점
struct GradientStop: Codable, Hashable, Identifiable, Equatable {
    let id: UUID
    var position: Double  // 0.0 ~ 1.0
    var colorIndex: UInt8 // 팔레트 참조

    init(id: UUID = UUID(), position: Double, colorIndex: UInt8) {
        self.id = id
        self.position = min(max(position, 0.0), 1.0)
        self.colorIndex = colorIndex
    }
}

/// 그라디언트 정의
struct GradientDefinition: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let type: GradientType
    let stops: [GradientStop]

    // Linear용 파라미터
    let angle: Double?  // 0-360도

    // Radial용 파라미터
    let centerX: Double?  // 0.0 ~ 1.0 (상대 좌표)
    let centerY: Double?
    let radius: Double?

    init(
        id: UUID = UUID(),
        name: String,
        type: GradientType,
        stops: [GradientStop],
        angle: Double? = nil,
        centerX: Double? = nil,
        centerY: Double? = nil,
        radius: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        // 정지점을 position 순으로 정렬
        self.stops = stops.sorted { $0.position < $1.position }
        self.angle = angle
        self.centerX = centerX
        self.centerY = centerY
        self.radius = radius
    }

    /// 선형 그라디언트 생성
    static func linear(
        name: String,
        stops: [GradientStop],
        angle: Double = 0
    ) -> GradientDefinition {
        return GradientDefinition(
            name: name,
            type: .linear,
            stops: stops,
            angle: angle
        )
    }

    /// 방사형 그라디언트 생성
    static func radial(
        name: String,
        stops: [GradientStop],
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        radius: Double = 0.5
    ) -> GradientDefinition {
        return GradientDefinition(
            name: name,
            type: .radial,
            stops: stops,
            centerX: centerX,
            centerY: centerY,
            radius: radius
        )
    }

    /// 각도 그라디언트 생성
    static func angular(
        name: String,
        stops: [GradientStop],
        centerX: Double = 0.5,
        centerY: Double = 0.5
    ) -> GradientDefinition {
        return GradientDefinition(
            name: name,
            type: .angular,
            stops: stops,
            centerX: centerX,
            centerY: centerY
        )
    }
}

/// 그라디언트 라이브러리 (프로젝트별)
struct GradientLibrary: Codable {
    private(set) var gradients: [UUID: GradientDefinition] = [:]

    /// 그라디언트 추가
    mutating func add(_ gradient: GradientDefinition) {
        gradients[gradient.id] = gradient
    }

    /// 그라디언트 제거
    mutating func remove(_ id: UUID) {
        gradients.removeValue(forKey: id)
    }

    /// ID로 그라디언트 가져오기
    subscript(id: UUID) -> GradientDefinition? {
        return gradients[id]
    }

    /// 모든 그라디언트 목록
    var all: [GradientDefinition] {
        return Array(gradients.values).sorted { $0.name < $1.name }
    }

    /// 그라디언트 개수
    var count: Int {
        return gradients.count
    }

    /// 빈 라이브러리인지 확인
    var isEmpty: Bool {
        return gradients.isEmpty
    }
}

// MARK: - Gradient Stop Interpolation

extension Array where Element == GradientStop {
    /// 주어진 position을 감싸는 두 stop을 찾아 반환 (통합된 보간 로직)
    /// - Parameter position: 0.0 ~ 1.0 범위의 위치
    /// - Returns: (하위 stop, 상위 stop, 보간 비율 t)
    func findSurroundingStops(at position: Double) -> (lower: GradientStop, upper: GradientStop, t: Double)? {
        let sortedStops = self.sorted { $0.position < $1.position }

        guard let first = sortedStops.first, let last = sortedStops.last else {
            return nil
        }

        // position이 범위 밖이면 양 끝 stop 사용
        if position <= first.position {
            return (first, first, 0.0)
        }
        if position >= last.position {
            return (last, last, 1.0)
        }

        // position을 감싸는 두 stop 찾기
        for i in 0..<(sortedStops.count - 1) {
            let lower = sortedStops[i]
            let upper = sortedStops[i + 1]

            if position >= lower.position && position <= upper.position {
                // 보간 비율 계산 (0.0 = lower, 1.0 = upper)
                let range = upper.position - lower.position
                let t = range > 0 ? (position - lower.position) / range : 0.0
                return (lower, upper, t)
            }
        }

        // fallback
        return (first, last, 0.5)
    }
}

// MARK: - Gradient Presets

extension GradientLibrary {
    /// 기본 그라디언트 프리셋
    static func defaultGradients() -> GradientLibrary {
        var library = GradientLibrary()

        // 흑백 선형 그라디언트 (팔레트 인덱스 0, 2 가정)
        let blackWhite = GradientDefinition.linear(
            name: "Black to White",
            stops: [
                GradientStop(position: 0.0, colorIndex: 0),  // Black
                GradientStop(position: 1.0, colorIndex: 2)   // White
            ],
            angle: 0
        )
        library.add(blackWhite)

        // 레인보우 그라디언트 (팔레트 인덱스 3-8 가정)
        let rainbow = GradientDefinition.linear(
            name: "Rainbow",
            stops: [
                GradientStop(position: 0.0, colorIndex: 3),   // Red
                GradientStop(position: 0.25, colorIndex: 5),  // Yellow
                GradientStop(position: 0.5, colorIndex: 7),   // Green
                GradientStop(position: 0.75, colorIndex: 11), // Blue
                GradientStop(position: 1.0, colorIndex: 13)   // Purple
            ],
            angle: 90
        )
        library.add(rainbow)

        return library
    }
}
