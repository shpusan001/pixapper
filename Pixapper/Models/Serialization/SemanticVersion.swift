//
//  SemanticVersion.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//

import Foundation

/// Semantic versioning (MAJOR.MINOR.PATCH)
/// 표준 버전 관리 시스템
struct SemanticVersion: Codable, Comparable, CustomStringConvertible, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    /// 현재 앱 버전 (새로운 필드 추가 시 여기만 업데이트)
    static let current = SemanticVersion(major: 1, minor: 1, patch: 0)

    /// 알려진 버전들
    static let v1_0 = SemanticVersion(major: 1, minor: 0, patch: 0)
    static let v1_1 = SemanticVersion(major: 1, minor: 1, patch: 0)

    init(major: Int, minor: Int, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// "1.1.0" 형식의 문자열에서 파싱
    init?(string: String) {
        let components = string.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 2 else { return nil }

        self.major = components[0]
        self.minor = components[1]
        self.patch = components.count > 2 ? components[2] : 0
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let versionString = try container.decode(String.self)

        guard let version = SemanticVersion(string: versionString) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid version format: \(versionString). Expected format: MAJOR.MINOR.PATCH"
            )
        }

        self = version
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    // MARK: - Comparable

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }

    // MARK: - CustomStringConvertible

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    // MARK: - Compatibility Checks

    /// 하위 호환성: 같은 major 버전이면 읽을 수 있음
    func canRead(_ other: SemanticVersion) -> Bool {
        return self.major == other.major && self >= other
    }

    /// Breaking change: major 버전이 다르면 호환 안 됨
    func isCompatible(with other: SemanticVersion) -> Bool {
        return self.major == other.major
    }
}
