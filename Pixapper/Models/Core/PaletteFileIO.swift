//
//  PaletteFileIO.swift
//  Pixapper
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI
import AppKit

/// 팔레트 파일 Import/Export 유틸리티
/// 지원 형식: .gpl (GIMP), .pal (Microsoft), .ase (Adobe)
class PaletteFileIO {

    // MARK: - GPL Format (GIMP Palette)

    /// GPL 파일에서 팔레트 로드
    /// - Parameter url: GPL 파일 경로
    /// - Returns: ColorPalette 또는 nil (실패 시)
    static func loadGPL(from url: URL) throws -> ColorPalette {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        guard lines.first == "GIMP Palette" else {
            throw PaletteError.invalidFormat
        }

        var name = "Imported Palette"
        var colors: [Color] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse name
            if trimmed.hasPrefix("Name:") {
                name = trimmed.replacingOccurrences(of: "Name:", with: "").trimmingCharacters(in: .whitespaces)
                continue
            }

            // Skip Columns line
            if trimmed.hasPrefix("Columns:") {
                continue
            }

            // Parse color line: "R G B [Name]"
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            if components.count >= 3,
               let r = Int(components[0]),
               let g = Int(components[1]),
               let b = Int(components[2]) {
                colors.append(Color(red: Double(r) / 255.0,
                                   green: Double(g) / 255.0,
                                   blue: Double(b) / 255.0))
            }
        }

        guard !colors.isEmpty else {
            throw PaletteError.noColors
        }

        return ColorPalette(name: name, colors: colors)
    }

    /// GPL 파일로 팔레트 저장
    /// - Parameters:
    ///   - palette: 저장할 팔레트
    ///   - url: 저장 경로
    static func saveGPL(palette: ColorPalette, to url: URL) throws {
        var content = "GIMP Palette\n"
        content += "Name: \(palette.name)\n"
        content += "Columns: 8\n"
        content += "#\n"

        for (index, color) in palette.colorArray.enumerated() {
            if let rgb = color.rgbComponents() {
                let r = Int(rgb.r * 255)
                let g = Int(rgb.g * 255)
                let b = Int(rgb.b * 255)
                content += "\(r) \(g) \(b)    Color \(index)\n"
            }
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - PAL Format (Microsoft RIFF)

    /// PAL 파일에서 팔레트 로드
    /// - Parameter url: PAL 파일 경로
    /// - Returns: ColorPalette 또는 nil (실패 시)
    static func loadPAL(from url: URL) throws -> ColorPalette {
        let data = try Data(contentsOf: url)

        // RIFF header verification
        guard data.count >= 24 else {
            throw PaletteError.invalidFormat
        }

        // Check "RIFF" signature
        let riffSignature = String(data: data[0..<4], encoding: .ascii)
        guard riffSignature == "RIFF" else {
            throw PaletteError.invalidFormat
        }

        // Check "PAL data" signature
        let palSignature = String(data: data[8..<16], encoding: .ascii)
        guard palSignature == "PAL data" else {
            throw PaletteError.invalidFormat
        }

        // Read version (should be 0x0300)
        let version = data.withUnsafeBytes { $0.load(fromByteOffset: 20, as: UInt16.self) }
        guard version == 0x0300 else {
            throw PaletteError.invalidFormat
        }

        // Read color count
        let colorCount = Int(data.withUnsafeBytes { $0.load(fromByteOffset: 22, as: UInt16.self) })
        guard colorCount > 0 && colorCount <= 256 else {
            throw PaletteError.invalidFormat
        }

        // Read colors (4 bytes each: R, G, B, Flags)
        var colors: [Color] = []
        var offset = 24

        for _ in 0..<colorCount {
            guard offset + 4 <= data.count else { break }

            let r = Double(data[offset]) / 255.0
            let g = Double(data[offset + 1]) / 255.0
            let b = Double(data[offset + 2]) / 255.0
            // data[offset + 3] is flags, usually 0

            colors.append(Color(red: r, green: g, blue: b))
            offset += 4
        }

        guard !colors.isEmpty else {
            throw PaletteError.noColors
        }

        return ColorPalette(name: url.deletingPathExtension().lastPathComponent, colors: colors)
    }

    /// PAL 파일로 팔레트 저장
    /// - Parameters:
    ///   - palette: 저장할 팔레트
    ///   - url: 저장 경로
    static func savePAL(palette: ColorPalette, to url: URL) throws {
        var data = Data()

        // RIFF header
        data.append("RIFF".data(using: .ascii)!)

        // File size (to be updated later)
        let fileSizeOffset = data.count
        data.append(UInt32(0).data)

        // PAL signature
        data.append("PAL data".data(using: .ascii)!)

        // Chunk size
        let colorCount = palette.count
        let chunkSize = UInt32(4 + colorCount * 4) // version(2) + count(2) + colors
        data.append(chunkSize.data)

        // Version
        data.append(UInt16(0x0300).data)

        // Color count
        data.append(UInt16(colorCount).data)

        // Colors
        for color in palette.colorArray {
            if let rgb = color.rgbComponents() {
                data.append(UInt8(rgb.r * 255))
                data.append(UInt8(rgb.g * 255))
                data.append(UInt8(rgb.b * 255))
                data.append(UInt8(0)) // Flags
            }
        }

        // Update file size
        let fileSize = UInt32(data.count - 8) // Exclude "RIFF" and size field
        data.replaceSubrange(fileSizeOffset..<fileSizeOffset+4, with: fileSize.data)

        try data.write(to: url)
    }

    // MARK: - ASE Format (Adobe Swatch Exchange)

    /// ASE 파일에서 팔레트 로드 (간단한 RGB 색상만 지원)
    /// - Parameter url: ASE 파일 경로
    /// - Returns: ColorPalette 또는 nil (실패 시)
    static func loadASE(from url: URL) throws -> ColorPalette {
        let data = try Data(contentsOf: url)

        guard data.count >= 12 else {
            throw PaletteError.invalidFormat
        }

        // Check "ASEF" signature
        let signature = String(data: data[0..<4], encoding: .ascii)
        guard signature == "ASEF" else {
            throw PaletteError.invalidFormat
        }

        // Read version (big-endian)
        let version = data.withUnsafeBytes {
            UInt16(bigEndian: $0.load(fromByteOffset: 4, as: UInt16.self))
        }
        guard version == 1 else {
            throw PaletteError.invalidFormat
        }

        // Read block count
        let blockCount = data.withUnsafeBytes {
            UInt32(bigEndian: $0.load(fromByteOffset: 8, as: UInt32.self))
        }

        var colors: [Color] = []
        var offset = 12

        for _ in 0..<blockCount {
            guard offset + 6 <= data.count else { break }

            // Block type (0x0001 = Color)
            let blockType = data.withUnsafeBytes {
                UInt16(bigEndian: $0.load(fromByteOffset: offset, as: UInt16.self))
            }
            offset += 2

            // Block length
            let blockLength = data.withUnsafeBytes {
                UInt32(bigEndian: $0.load(fromByteOffset: offset, as: UInt32.self))
            }
            offset += 4

            if blockType == 0x0001 { // Color block
                // Parse color name (skip for now)
                guard offset + 2 <= data.count else { break }
                let nameLength = Int(data.withUnsafeBytes {
                    UInt16(bigEndian: $0.load(fromByteOffset: offset, as: UInt16.self))
                })
                offset += 2 + nameLength * 2 // UTF-16 name

                // Color model (skip, assume RGB)
                guard offset + 4 <= data.count else { break }
                offset += 4

                // RGB values (3 floats, big-endian)
                guard offset + 12 <= data.count else { break }

                let r = Double(data.withUnsafeBytes {
                    Float32(bitPattern: UInt32(bigEndian: $0.load(fromByteOffset: offset, as: UInt32.self)))
                })
                let g = Double(data.withUnsafeBytes {
                    Float32(bitPattern: UInt32(bigEndian: $0.load(fromByteOffset: offset + 4, as: UInt32.self)))
                })
                let b = Double(data.withUnsafeBytes {
                    Float32(bitPattern: UInt32(bigEndian: $0.load(fromByteOffset: offset + 8, as: UInt32.self)))
                })

                colors.append(Color(red: r, green: g, blue: b))
                offset += 12

                // Skip color type (2 bytes)
                offset += 2
            } else {
                // Skip unknown block
                offset += Int(blockLength)
            }
        }

        guard !colors.isEmpty else {
            throw PaletteError.noColors
        }

        return ColorPalette(name: url.deletingPathExtension().lastPathComponent, colors: colors)
    }

    /// ASE 파일로 팔레트 저장
    /// - Parameters:
    ///   - palette: 저장할 팔레트
    ///   - url: 저장 경로
    static func saveASE(palette: ColorPalette, to url: URL) throws {
        var data = Data()

        // ASEF signature
        data.append("ASEF".data(using: .ascii)!)

        // Version (1.0, big-endian)
        data.append(UInt16(1).bigEndian.data)
        data.append(UInt16(0).bigEndian.data)

        // Block count
        data.append(UInt32(palette.count).bigEndian.data)

        // Write color blocks
        for (index, color) in palette.colorArray.enumerated() {
            guard let rgb = color.rgbComponents() else { continue }

            // Block type (0x0001 = Color)
            data.append(UInt16(0x0001).bigEndian.data)

            // Calculate block length
            let name = "Color \(index)"
            let nameLength = UInt16(name.count + 1) // +1 for null terminator
            let blockLength = UInt32(2 + nameLength * 2 + 4 + 12 + 2) // name length + name + color model + RGB + type
            data.append(blockLength.bigEndian.data)

            // Name length
            data.append(nameLength.bigEndian.data)

            // Name (UTF-16 big-endian)
            for char in name.utf16 {
                data.append(UInt16(char).bigEndian.data)
            }
            data.append(UInt16(0).bigEndian.data) // Null terminator

            // Color model ("RGB ")
            data.append("RGB ".data(using: .ascii)!)

            // RGB values (floats, big-endian)
            data.append(Float32(rgb.r).bitPattern.bigEndian.data)
            data.append(Float32(rgb.g).bitPattern.bigEndian.data)
            data.append(Float32(rgb.b).bitPattern.bigEndian.data)

            // Color type (0 = Global, 1 = Spot, 2 = Normal)
            data.append(UInt16(2).bigEndian.data)
        }

        try data.write(to: url)
    }
}

// MARK: - Error Types

enum PaletteError: LocalizedError {
    case invalidFormat
    case noColors
    case unsupportedColorModel

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid palette file format"
        case .noColors:
            return "No colors found in palette file"
        case .unsupportedColorModel:
            return "Unsupported color model (only RGB supported)"
        }
    }
}

// MARK: - Data Extension

extension UInt16 {
    var data: Data {
        var value = self
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }

    var bigEndian: UInt16 {
        return UInt16(bigEndian: self)
    }
}

extension UInt32 {
    var data: Data {
        var value = self
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }

    var bigEndian: UInt32 {
        return UInt32(bigEndian: self)
    }
}

extension UInt8 {
    init(_ double: Double) {
        let value = Int(double * 255)
        let clamped = Swift.max(0, Swift.min(255, value))
        self = UInt8(clamped)
    }
}
