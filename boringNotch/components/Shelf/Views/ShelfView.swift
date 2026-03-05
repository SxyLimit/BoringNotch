//
//  ShelfItemView.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import SwiftUI
import AppKit
import Defaults

struct ShelfView: View {
    @EnvironmentObject var vm: BoringViewModel
    @StateObject var tvm = ShelfStateViewModel.shared
    @StateObject var selection = ShelfSelectionModel.shared
    @StateObject private var quickLookService = QuickLookService()
    private let spacing: CGFloat = 8

    var body: some View {
        HStack(spacing: 12) {
            FileShareView()
                .aspectRatio(1, contentMode: .fit)
                .environmentObject(vm)
            panel
                .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
                    handleDrop(providers: providers)
                }
        }
        // Bind Quick Look to shelf selection
        .onChange(of: selection.selectedIDs) {
            updateQuickLookSelection()
        }
        .quickLookPresenter(using: quickLookService)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !selection.isDragging else { return false }
        vm.dropEvent = true
        ShelfStateViewModel.shared.load(providers)
        return true
    }
    
    private func updateQuickLookSelection() {
        guard quickLookService.isQuickLookOpen && !selection.selectedIDs.isEmpty else { return }
        
        let selectedItems = selection.selectedItems(in: tvm.items)
        let urls: [URL] = selectedItems.compactMap { item in
            if let fileURL = item.fileURL {
                return fileURL
            }
            if case .link(let url) = item.kind {
                return url
            }
            return nil
        }
        
        if !urls.isEmpty {
            quickLookService.updateSelection(urls: urls)
        }
    }

    var panel: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                vm.dragDetectorTargeting
                    ? Color.accentColor.opacity(0.9)
                    : Color.white.opacity(0.1),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10])
            )
            .overlay {
                content
                    .padding()
            }
            .transaction { transaction in
                transaction.animation = vm.animation
            }
            .contentShape(Rectangle())
            .onTapGesture { selection.clear() }
    }

    var content: some View {
        Group {
            if tvm.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down")
                        .symbolVariant(.fill)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white, .gray)
                        .imageScale(.large)
                    
                    Text("Drop files here")
                        .foregroundStyle(.gray)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.medium)
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: spacing) {
                        ForEach(tvm.items) { item in
                            ShelfItemView(item: item)
                                .environmentObject(quickLookService)
                        }
                    }
                }
                .padding(-spacing)
                .scrollIndicators(.never)
                .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
                    handleDrop(providers: providers)
                }
            }
        }
        .onAppear {
            ShelfStateViewModel.shared.cleanupInvalidItems()
        }
    }
}

struct FolderShortcutsView: View {
    @Default(.folderShortcuts) private var folderShortcuts
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            panel
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
            }
        }
        .onAppear {
            cleanupInvalidShortcuts()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label("Folders", systemImage: "folder.fill")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button {
                openFolderPicker()
            } label: {
                Label("Add Folder", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(7)
            .background(Color.white.opacity(0.1))
            .clipShape(Circle())
            .help("Add folders")
        }
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8]))
            .overlay {
                content
                    .padding(12)
            }
    }

    @ViewBuilder
    private var content: some View {
        if folderShortcuts.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white, .gray)
                    .imageScale(.large)

                Text("No folder shortcuts")
                    .foregroundStyle(.gray)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.medium)

                Button("Add Folder") {
                    openFolderPicker()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(folderShortcuts) { shortcut in
                        shortcutRow(for: shortcut)
                    }
                }
            }
            .scrollIndicators(.never)
            .frame(maxHeight: 170)
        }
    }

    private func shortcutRow(for shortcut: FolderShortcutItem) -> some View {
        HStack(spacing: 8) {
            Button {
                openShortcut(shortcut)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.yellow)
                    Text(shortcut.name)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 6)
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Open in Finder") { openShortcut(shortcut) }
                Button("Remove", role: .destructive) { removeShortcut(shortcut) }
            }

            Button {
                removeShortcut(shortcut)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
    }

    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.message = "Choose folders to add shortcuts"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else { return }
        addFolders(panel.urls)
    }

    private func addFolders(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        statusMessage = nil

        var updatedShortcuts = folderShortcuts
        var existingPaths = Set(updatedShortcuts.compactMap { resolvedPath(for: $0) })
        var failedToAdd = false

        for url in urls where isDirectory(url) {
            let normalizedPath = url.standardizedFileURL.path
            guard !existingPaths.contains(normalizedPath) else { continue }

            do {
                let bookmark = try Bookmark(url: url)
                updatedShortcuts.append(
                    FolderShortcutItem(
                        name: preferredFolderName(for: url),
                        bookmarkData: bookmark.data
                    )
                )
                existingPaths.insert(normalizedPath)
            } catch {
                failedToAdd = true
            }
        }

        folderShortcuts = updatedShortcuts
        if failedToAdd {
            statusMessage = "Some folders could not be added."
        }
    }

    private func openShortcut(_ shortcut: FolderShortcutItem) {
        statusMessage = nil
        guard let url = resolvedURL(for: shortcut, refreshBookmark: true) else {
            removeShortcut(shortcut)
            statusMessage = "This folder is no longer available and was removed."
            return
        }

        url.accessSecurityScopedResource { accessibleURL in
            NSWorkspace.shared.open(accessibleURL)
        }
    }

    private func removeShortcut(_ shortcut: FolderShortcutItem) {
        folderShortcuts.removeAll { $0.id == shortcut.id }
    }

    private func resolvedPath(for shortcut: FolderShortcutItem) -> String? {
        guard let url = resolvedURL(for: shortcut, refreshBookmark: false) else { return nil }
        return url.standardizedFileURL.path
    }

    private func resolvedURL(for shortcut: FolderShortcutItem, refreshBookmark: Bool) -> URL? {
        let bookmark = Bookmark(data: shortcut.bookmarkData)
        let result = bookmark.resolve()

        if refreshBookmark, let refreshedData = result.refreshedData, refreshedData != shortcut.bookmarkData {
            updateBookmark(shortcutID: shortcut.id, bookmarkData: refreshedData)
        }

        return result.url
    }

    private func updateBookmark(shortcutID: UUID, bookmarkData: Data) {
        guard let index = folderShortcuts.firstIndex(where: { $0.id == shortcutID }) else { return }
        var updated = folderShortcuts
        updated[index].bookmarkData = bookmarkData
        folderShortcuts = updated
    }

    private func cleanupInvalidShortcuts() {
        let validShortcuts = folderShortcuts.filter { shortcut in
            guard let url = resolvedURL(for: shortcut, refreshBookmark: false) else { return false }
            return url.accessSecurityScopedResource { accessibleURL in
                var isDirectoryFlag: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: accessibleURL.path, isDirectory: &isDirectoryFlag)
                return exists && isDirectoryFlag.boolValue
            }
        }
        if validShortcuts != folderShortcuts {
            folderShortcuts = validShortcuts
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private func preferredFolderName(for url: URL) -> String {
        (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? url.lastPathComponent
    }
}
