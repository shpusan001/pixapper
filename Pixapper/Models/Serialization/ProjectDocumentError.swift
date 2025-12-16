//
//  ProjectDocumentError.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//

import Foundation

/// 프로젝트 문서 로드/저장 시 발생하는 에러
enum ProjectDocumentError: LocalizedError, Sendable {
    case incompatibleVersion(file: SemanticVersion, app: SemanticVersion)
    case unsupportedVersion(SemanticVersion)
    case invalidData(String)
    case validationFailed(String)
    case corruptedFile(String)
    case migrationFailed(from: SemanticVersion, to: SemanticVersion, reason: String)

    var errorDescription: String? {
        switch self {
        case .incompatibleVersion(let file, let app):
            return "This file was created with version \(file), which is incompatible with the current app version \(app). Please update the app."

        case .unsupportedVersion(let version):
            return "File version \(version) is not supported. This file may have been created with a newer version of the app."

        case .invalidData(let reason):
            return "Invalid file data: \(reason)"

        case .validationFailed(let reason):
            return "File validation failed: \(reason)"

        case .corruptedFile(let reason):
            return "The file appears to be corrupted: \(reason)"

        case .migrationFailed(let from, let to, let reason):
            return "Failed to migrate from version \(from) to \(to): \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .incompatibleVersion:
            return "Try opening this file with a compatible version of the app."

        case .unsupportedVersion:
            return "Update to the latest version of the app to open this file."

        case .invalidData, .corruptedFile:
            return "The file may be damaged. Try opening a backup if available."

        case .validationFailed:
            return "Check that the file hasn't been manually edited."

        case .migrationFailed:
            return "This file may need to be opened with an intermediate version first."
        }
    }
}
