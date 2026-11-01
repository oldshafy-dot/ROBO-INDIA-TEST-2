import SwiftUI
import Foundation
import UIKit

struct PatchProjectsView: View {
    @EnvironmentObject private var store: PatchProjectStore

    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    @State private var workingPatchIDs = Set<UUID>()
    @State private var isRestoringAll = false
    @State private var syncMessage: String?
    @State private var isSyncing = false
    @State private var selectedCategory: PatchCategory = .ffIndia

    private enum PatchCategory: String, CaseIterable {
        case ffIndia = "FF India"
        case bgmi = "BGMI"
    }

    private var ffIndiaItems: [PatchLibraryItem] {
        store.items.filter { item in
            let value = "\(item.packageURL.lastPathComponent) \(item.project?.name ?? "")".lowercased()
            return value.contains("body hs") || value.contains("aim head") || value.contains("neck hs") || value.contains("magic hs") || value.contains("ffth") || value.contains("ff india") || value.contains("free fire india")
        }
    }

    private var bgmiItems: [PatchLibraryItem] {
        store.items.filter { item in
            let value = "\(item.packageURL.lastPathComponent) \(item.project?.name ?? "")".lowercased()
            return value.contains("ffmax") || value.contains("bgmi") || value.contains("free fire max")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    categoryPicker

                    categorySection(
                        title: selectedCategory.rawValue,
                        items: selectedItems,
                        emptyMessage: "Patch is not available yet. Next patch will be available soon."
                    )

                    Button {
                        restoreAll()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                            Text(isRestoringAll ? "Restoring…" : "Restore All")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.30, blue: 0.55).opacity(0.70),
                                    Color(red: 0.12, green: 0.48, blue: 0.82).opacity(0.42)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRestoringAll || store.items.isEmpty)

                    if let syncMessage {
                        Text(syncMessage)
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.45, green: 0.72, blue: 1.0))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Functions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                Task { await syncRemotePatchArchive() }
            }
        }
    }

    private var selectedItems: [PatchLibraryItem] {
        switch selectedCategory {
        case .ffIndia:
            return ffIndiaItems
        case .bgmi:
            return bgmiItems
        }
    }

    private var categoryPicker: some View {
        HStack(spacing: 8) {
            ForEach(PatchCategory.allCases, id: \.self) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedCategory = category
                    }
                } label: {
                    Text(category.rawValue)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(
                            selectedCategory == category
                                ? .white
                                : Color(red: 0.48, green: 0.72, blue: 1.0)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedCategory == category
                                ? LinearGradient(
                                    colors: [
                                        Color(red: 0.08, green: 0.38, blue: 0.72),
                                        Color(red: 0.18, green: 0.62, blue: 0.95)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color(red: 0.05, green: 0.15, blue: 0.25).opacity(0.92),
                                        Color.white.opacity(0.06)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    Color(red: 0.22, green: 0.60, blue: 1.0).opacity(0.55),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            Color(red: 0.04, green: 0.12, blue: 0.20).opacity(0.95),
            in: RoundedRectangle(cornerRadius: 15)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    Color(red: 0.18, green: 0.52, blue: 0.92).opacity(0.48),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private func categorySection(
        title: String,
        items: [PatchLibraryItem],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            if items.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(items) { item in
                    patchRow(item)
                }
            }
        }
    }

    private func patchRow(_ item: PatchLibraryItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.project?.name ?? item.packageURL.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(item.packageURL.lastPathComponent)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.45, green: 0.68, blue: 1.0).opacity(0.85))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if item.isLocked {
                Text("LOCKED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.orange)
            } else {
                let enabled = DevicePatchService.latestReceipt(projectID: item.id) != nil

                Button {
                    togglePatch(item, enabled: !enabled)
                } label: {
                    HStack(spacing: 5) {
                        if workingPatchIDs.contains(item.id) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.65)
                        }
                        Text(workingPatchIDs.contains(item.id) ? "…" : (enabled ? "ON" : "OFF"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 30)
                    .background(
                        enabled
                            ? Color(red: 0.08, green: 0.55, blue: 0.95).opacity(0.90)
                            : Color(red: 0.08, green: 0.24, blue: 0.38).opacity(0.75),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .disabled(workingPatchIDs.contains(item.id) || isRestoringAll)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.20, blue: 0.34).opacity(0.62),
                    Color.white.opacity(0.045)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    Color(red: 0.18, green: 0.52, blue: 0.92).opacity(0.34),
                    lineWidth: 1
                )
        )
    }

    private func togglePatch(_ item: PatchLibraryItem, enabled: Bool) {
        guard let project = item.project else { return }
        guard !workingPatchIDs.contains(item.id) else { return }

        workingPatchIDs.insert(item.id)

        Task.detached(priority: .userInitiated) {
            do {
                if enabled {
                    _ = try DevicePatchService.apply(project: project)
                } else if let receipt = DevicePatchService.latestReceipt(projectID: item.id) {
                    try DevicePatchService.restore(receipt: receipt)
                }

                await MainActor.run {
                    workingPatchIDs.remove(item.id)
                    store.reload()
                }
            } catch {
                await MainActor.run {
                    workingPatchIDs.remove(item.id)
                    syncMessage = enabled
                        ? "Failed to apply \(project.name)."
                        : "Failed to restore \(project.name)."
                }
            }
        }
    }

    private func restoreAll() {
        guard !isRestoringAll else { return }
        isRestoringAll = true
        syncMessage = nil

        let receipts = store.items.compactMap { item -> (UUID, PatchTransactionReceipt)? in
            guard let receipt = DevicePatchService.latestReceipt(projectID: item.id) else {
                return nil
            }
            return (item.id, receipt)
        }

        Task.detached(priority: .userInitiated) {
            var restoreFailed = false

            for (_, receipt) in receipts {
                do {
                    try DevicePatchService.restore(receipt: receipt)
                } catch {
                    restoreFailed = true
                }
            }

            let restoreResult = restoreFailed

            await MainActor.run {
                isRestoringAll = false
                store.reload()
                syncMessage = restoreResult
                    ? "Some patches could not be restored."
                    : "All applied patches were restored."
            }
        }
    }

    private struct PatchArchiveManifest: Decodable {
        let version: String?
        let download_url: String?
        let active: Bool?
    }

    @MainActor
    private func syncRemotePatchArchive() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let manifestURLs = [
            URL(string: "https://shafaykeyauthadmin.lovable.app/api/public/v1/patch/latest")!,
            URL(string: "https://roboexternalauth.lovable.app/api/public/patch?game=free_fire")!
        ]

        var lastError = "Patch update could not be checked."

        for manifestURL in manifestURLs {
            do {
                var request = URLRequest(url: manifestURL)
                request.timeoutInterval = 20
                request.setValue("application/json", forHTTPHeaderField: "Accept")

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    throw PatchSyncError.invalidResponse
                }

                guard (200..<300).contains(http.statusCode) else {
                    throw PatchSyncError.http(http.statusCode)
                }

                let manifest = try JSONDecoder().decode(PatchArchiveManifest.self, from: data)

                guard manifest.active != false else {
                    throw PatchSyncError.inactive
                }

                guard let rawDownloadURL = manifest.download_url,
                      let downloadURL = URL(string: rawDownloadURL),
                      downloadURL.scheme == "https" else {
                    throw PatchSyncError.missingDownloadURL
                }

                let (archiveData, archiveResponse) = try await URLSession.shared.data(from: downloadURL)

                guard let archiveHTTP = archiveResponse as? HTTPURLResponse,
                      (200..<300).contains(archiveHTTP.statusCode) else {
                    throw PatchSyncError.archiveDownloadFailed
                }

                let tempRoot = FileManager.default.temporaryDirectory
                    .appendingPathComponent("robo-patches-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(
                    at: tempRoot,
                    withIntermediateDirectories: true
                )
                defer { try? FileManager.default.removeItem(at: tempRoot) }

                let archiveURL = tempRoot.appendingPathComponent("ROBO-PATCHES.zip")
                try archiveData.write(to: archiveURL, options: .atomic)

                let extractionRoot = tempRoot.appendingPathComponent("extracted", isDirectory: true)
                try FileManager.default.createDirectory(
                    at: extractionRoot,
                    withIntermediateDirectories: true
                )

                let result = try ZIPArchiveExtractor.extract(
                    archiveURL: archiveURL,
                    into: extractionRoot
                )

                let packageURLs = try findPatchPackages(
                    in: result.destinationURL,
                    fileManager: .default
                )

                guard !packageURLs.isEmpty else {
                    throw PatchSyncError.noPatchesFound
                }

                var imported = 0

                for packageURL in packageURLs {
                    let packageData = try Data(contentsOf: packageURL)

                    while store.isBusy {
                        try await Task.sleep(nanoseconds: 150_000_000)
                    }

                    if store.importPackage(data: packageData) {
                        imported += 1
                    }

                    while store.isBusy {
                        try await Task.sleep(nanoseconds: 150_000_000)
                    }
                }

                UserDefaults.standard.set(
                    downloadURL.absoluteString,
                    forKey: "robo.patch.archive.url"
                )
                UserDefaults.standard.set(
                    manifest.version ?? "",
                    forKey: "robo.patch.archive.version"
                )

                store.reload()
                syncMessage = imported > 0
                    ? "Patch update installed (\(imported) patches)."
                    : "Patch archive checked."
                return

            } catch {
                lastError = error.localizedDescription
            }
        }

        store.reload()
        syncMessage = lastError
    }

    private enum PatchSyncError: LocalizedError {
        case invalidResponse
        case http(Int)
        case inactive
        case missingDownloadURL
        case archiveDownloadFailed
        case noPatchesFound

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Patch server returned an invalid response."
            case .http(let code):
                return "Patch server returned HTTP \(code)."
            case .inactive:
                return "The current patch archive is inactive."
            case .missingDownloadURL:
                return "Patch server did not provide a download URL."
            case .archiveDownloadFailed:
                return "The patch ZIP could not be downloaded."
            case .noPatchesFound:
                return "The patch ZIP contains no .3105 patch files."
            }
        }
    }

    private func findPatchPackages(
        in root: URL,
        fileManager: FileManager
    ) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            )
            guard values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  url.pathExtension.lowercased() == "3105" else {
                continue
            }
            result.append(url)
        }

        return result
    }
}
