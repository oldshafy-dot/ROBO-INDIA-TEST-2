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
            return value.contains("in body") || value.contains("in rag") || value.contains("in neck") || value.contains("in head") || value.contains("body hs") || value.contains("aim head") || value.contains("neck hs") || value.contains("magic hs") || value.contains("ffth") || value.contains("ff india") || value.contains("free fire india")
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
                                        Color(red: 0.12, green: 0.52, blue: 0.86)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.045),
                                        Color.white.opacity(0.025)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    Color.white.opacity(0.22),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            Color.white.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 15)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    Color.white.opacity(0.20),
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
                            ? Color.green.opacity(0.90)
                            : Color(red: 0.08, green: 0.38, blue: 0.72).opacity(0.90),
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
                    Color.white.opacity(0.045),
                    Color.white.opacity(0.025)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    Color.white.opacity(0.20),
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

    private struct PatchOptionsResponse: Decodable {
        let success: Bool
        let categories: [PatchCategoryResponse]
    }

    private struct PatchCategoryResponse: Decodable {
        let category: String
        let name: String
        let options: [RemotePatchOption]
    }

    private struct RemotePatchOption: Decodable {
        let id: String
        let category: String
        let name: String
        let sort_order: Int
        let enabled: Bool
        let has_file: Bool
        let selectable: Bool
        let file_name: String?
        let download_url: String?
        let updated_at: String?
    }

    @MainActor
    private func syncRemotePatchArchive() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            var request = URLRequest(
                url: URL(string: "https://shafaykeyauthadmin.lovable.app/api/public/v1/patch/options")!
            )
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw PatchSyncError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
            }

            let payload = try JSONDecoder().decode(PatchOptionsResponse.self, from: data)
            guard payload.success else {
                throw PatchSyncError.invalidResponse
            }

            let allOptions = payload.categories.flatMap(\.options)
            let availableOptions = allOptions
                .filter { $0.enabled && $0.has_file && $0.selectable }
                .sorted { $0.sort_order < $1.sort_order }

            guard !availableOptions.isEmpty else {
                store.reload()
                syncMessage = "No online patches are available."
                return
            }

            var packageData: [Data] = []
            var failedNames: [String] = []

            for option in availableOptions {
                guard let rawURL = option.download_url,
                      let url = URL(string: rawURL),
                      url.scheme == "https" else {
                    failedNames.append(option.name)
                    continue
                }

                do {
                    var downloadRequest = URLRequest(url: url)
                    downloadRequest.timeoutInterval = 60
                    downloadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

                    let (patchData, patchResponse) = try await URLSession.shared.data(for: downloadRequest)
                    guard let patchHTTP = patchResponse as? HTTPURLResponse,
                          (200..<300).contains(patchHTTP.statusCode),
                          !patchData.isEmpty else {
                        throw PatchSyncError.archiveDownloadFailed
                    }

                    packageData.append(patchData)
                } catch {
                    failedNames.append(option.name)
                }
            }

            let imported = await store.importPackages(data: packageData)
            store.reload()

            if imported > 0 {
                syncMessage = failedNames.isEmpty
                    ? "Online patches updated ((imported) patches)."
                    : "Updated (imported) patches. Some downloads failed."
            } else if !packageData.isEmpty {
                syncMessage = "Online patches were downloaded but could not be installed."
            } else {
                syncMessage = "Online patch downloads failed."
            }
        } catch {
            store.reload()
            syncMessage = error.localizedDescription
        }
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
