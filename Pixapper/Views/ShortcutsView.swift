//
//  ShortcutsView.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//

import SwiftUI

/// 단축키 조회 창
struct ShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: ShortcutCategory? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(20)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content
            HStack(spacing: 0) {
                // Sidebar - Categories
                categoryList
                    .frame(width: 200)
                    .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Main - Shortcuts
                shortcutsList
            }
        }
        .frame(width: 900, height: 650)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.escape)
            }

            // Search
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))

                TextField("Search shortcuts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Category List (Sidebar)

    private var categoryList: some View {
        VStack(spacing: 0) {
            // Header
            Text("Categories")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // All Categories
            CategoryRow(
                category: nil,
                isSelected: selectedCategory == nil,
                count: filteredShortcuts.count
            )
            .onTapGesture {
                selectedCategory = nil
            }
            .padding(.horizontal, 8)

            Divider()
                .padding(.vertical, 8)

            // Individual Categories
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(ShortcutCategory.allCases, id: \.self) { category in
                        CategoryRow(
                            category: category,
                            isSelected: selectedCategory == category,
                            count: filteredShortcuts(in: category).count
                        )
                        .onTapGesture {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer()
        }
        .padding(.bottom, 16)
    }

    // MARK: - Shortcuts List (Main)

    private var shortcutsList: some View {
        ScrollView {
            VStack(spacing: 24) {
                if selectedCategory == nil {
                    // Show all categories
                    ForEach(ShortcutCategory.allCases, id: \.self) { category in
                        if !filteredShortcuts(in: category).isEmpty {
                            CategorySection(
                                category: category,
                                shortcuts: filteredShortcuts(in: category)
                            )
                        }
                    }
                } else if let category = selectedCategory {
                    // Show selected category only
                    CategorySection(
                        category: category,
                        shortcuts: filteredShortcuts(in: category)
                    )
                }

                // Empty state
                if filteredShortcuts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("No shortcuts found")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Filtered Shortcuts

    private var filteredShortcuts: [Shortcut] {
        if searchText.isEmpty {
            return Shortcut.allCases
        }

        let lowercased = searchText.lowercased()
        return Shortcut.allCases.filter { shortcut in
            shortcut.menuTitle.lowercased().contains(lowercased) ||
            shortcut.description.lowercased().contains(lowercased) ||
            shortcut.shortcutDisplayString.lowercased().contains(lowercased)
        }
    }

    private func filteredShortcuts(in category: ShortcutCategory) -> [Shortcut] {
        filteredShortcuts.filter { $0.category == category }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: ShortcutCategory?
    let isSelected: Bool
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(category?.displayName ?? "All")
                .font(.system(size: 13))
                .foregroundColor(isSelected ? Color.primary : Color.secondary)
                .fontWeight(isSelected ? .medium : .regular)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(isSelected ? Color.accentColor : Color.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Category Section

struct CategorySection: View {
    let category: ShortcutCategory
    let shortcuts: [Shortcut]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category Header
            HStack {
                Text(category.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(shortcuts.count) shortcut\(shortcuts.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // Shortcuts Table
            VStack(spacing: 0) {
                ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    ShortcutRow(shortcut: shortcut)

                    if index < shortcuts.count - 1 {
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let shortcut: Shortcut

    var body: some View {
        HStack(spacing: 20) {
            // Action name
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.menuTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(shortcut.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 20)

            // Keyboard shortcut
            if shortcut.defaultKeyboardShortcut != nil {
                HStack(spacing: 2) {
                    ForEach(shortcut.shortcutDisplayString.map { String($0) }, id: \.self) { char in
                        if ["⌘", "⇧", "⌃", "⌥"].contains(char) {
                            // Modifier key
                            Text(char)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        } else {
                            // Regular key
                            Text(char)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(nsColor: .windowBackgroundColor))
                                        .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
                                )
                        }
                    }
                }
                .fixedSize()
            } else {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Preview

#Preview {
    ShortcutsView()
}
