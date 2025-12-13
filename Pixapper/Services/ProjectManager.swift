//
//  ProjectManager.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

/// 프로젝트 저장/불러오기 관리자
class ProjectManager {
    static let shared = ProjectManager()

    /// 프로젝트 파일 확장자
    static let fileExtension = "pixapper"

    /// 프로젝트 파일 타입
    static let fileType = "com.pixapper.project"

    private init() {}

    /// 프로젝트를 JSON 파일로 저장
    /// - Parameters:
    ///   - document: 저장할 프로젝트 문서
    ///   - url: 저장할 파일 경로 (nil이면 사용자에게 묻기)
    /// - Returns: 저장된 파일 경로 (취소 시 nil)
    func save(document: ProjectDocument, to url: URL? = nil) throws -> URL? {
        var mutableDocument = document
        mutableDocument.updateModifiedDate()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(mutableDocument)

        let saveURL: URL?

        if let url = url {
            saveURL = url
        } else {
            // 사용자에게 저장 위치 묻기
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.init(filenameExtension: ProjectManager.fileExtension)!]
            savePanel.nameFieldStringValue = "Untitled.\(ProjectManager.fileExtension)"
            savePanel.title = "Save Pixapper Project"
            savePanel.message = "Choose a location to save your project"

            let response = savePanel.runModal()
            guard response == .OK, let url = savePanel.url else {
                return nil  // 사용자가 취소함
            }
            saveURL = url
        }

        guard let finalURL = saveURL else { return nil }

        try jsonData.write(to: finalURL, options: .atomic)
        return finalURL
    }

    /// 프로젝트를 JSON 파일에서 불러오기
    /// - Parameter url: 불러올 파일 경로 (nil이면 사용자에게 묻기)
    /// - Returns: 불러온 프로젝트 문서 (취소 시 nil)
    func load(from url: URL? = nil) throws -> ProjectDocument? {
        let loadURL: URL?

        if let url = url {
            loadURL = url
        } else {
            // 사용자에게 파일 선택 묻기
            let openPanel = NSOpenPanel()
            openPanel.allowedContentTypes = [.init(filenameExtension: ProjectManager.fileExtension)!]
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            openPanel.title = "Open Pixapper Project"
            openPanel.message = "Choose a project file to open"

            let response = openPanel.runModal()
            guard response == .OK, let url = openPanel.url else {
                return nil  // 사용자가 취소함
            }
            loadURL = url
        }

        guard let finalURL = loadURL else { return nil }

        let jsonData = try Data(contentsOf: finalURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let document = try decoder.decode(ProjectDocument.self, from: jsonData)
        return document
    }

    /// 프로젝트 파일의 유효성 검사
    func validate(url: URL) -> Bool {
        guard url.pathExtension == ProjectManager.fileExtension else {
            return false
        }

        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            _ = try decoder.decode(ProjectDocument.self, from: jsonData)
            return true
        } catch {
            return false
        }
    }
}
