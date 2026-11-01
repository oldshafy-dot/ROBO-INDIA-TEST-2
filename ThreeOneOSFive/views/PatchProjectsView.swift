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

    private var ffIndiaItems: [PatchLibraryItem] {
        store.items.filter { item in
            let value = "\(item.packageURL.lastPathComponent) \(item.project?.name ?? "")".lowercased()
            return value.contains("ffth") || value.contains("ff india") || value.contains("free fire india")
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
                VStack(alignment: .leading, spacing: 16) {
                    telegramRow

                    categorySection(
                        title: "FF India",
                        items: ffIndiaItems,
                        emptyMessage: "Patch is not available yet. Next patch will be available soon."
                    )

                    categorySection(
                        title: "BGMI",
                        items: bgmiItems,
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
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isRestoringAll || store.items.isEmpty)

                    if let syncMessage {
                        Text(syncMessage)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
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

    private var telegramRow: some View {
        Button {
            guard let url = URL(string: "https://t.me/roboios") else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Official Telegram Channel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("t.me/roboios")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.35, green: 0.68, blue: 1.0))
                }

                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(12)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func categorySection(
        title: String,
        items: [PatchLibraryItem],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            if items.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(.vertical, 8)
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
                    .foregroundStyle(.white.opacity(0.45))
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
                            ? Color.green.opacity(0.75)
                            : Color.white.opacity(0.12),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .disabled(workingPatchIDs.contains(item.id) || isRestoringAll)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
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
            var failed = false

            for (_, receipt) in receipts {
                do {
                    try DevicePatchService.restore(receipt: receipt)
                } catch {
                    failed = true
                }
            }

            await MainActor.run {
                isRestoringAll = false
                store.reload()
                syncMessage = failed
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

        let games = ["free_fire", "free_fire_max"]

        for game in games {
            guard let manifestURL = URL(string: "https://roboexternalauth.lovable.app/api/public/patch?game=\(game)") else {
                continue
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: manifestURL)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    continue
                }

                let manifest = try JSONDecoder().decode(PatchArchiveManifest.self, from: data)
                guard manifest.active != false,
                      let rawDownloadURL = manifest.download_url,
                      let downloadURL = URL(string: rawDownloadURL),
                      downloadURL.scheme == "https" else {
                    continue
                }

                let defaults = UserDefaults.standard
                let savedURL = defaults.string(forKey: "robo.patch.archive.url")
                let savedVersion = defaults.string(forKey: "robo.patch.archive.version")
                if savedURL == downloadURL.absoluteString,
                   savedVersion == manifest.version,
                   !store.items.isEmpty {
                    return
                }

                let (archiveData, archiveResponse) = try await URLSession.shared.data(from: downloadURL)
                guard let archiveHTTP = archiveResponse as? HTTPURLResponse,
                      (200..<300).contains(archiveHTTP.statusCode) else {
                    continue
                }

                let tempRoot = FileManager.default.temporaryDirectory
                    .appendingPathComponent("robo-patches-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: tempRoot) }

                let archiveURL = tempRoot.appendingPathComponent("ROBO-PATCHES.zip")
                try archiveData.write(to: archiveURL, options: .atomic)

                let extractionRoot = tempRoot.appendingPathComponent("extracted", isDirectory: true)
                try FileManager.default.createDirectory(at: extractionRoot, withIntermediateDirectories: true)
                let result = try ZIPArchiveExtractor.extract(
                    archiveURL: archiveURL,
                    into: extractionRoot
                )

                let packageURLs = try findPatchPackages(
                    in: result.destinationURL,
                    fileManager: .default
                )

                var imported = 0
                for packageURL in packageURLs {
                    let packageData = try Data(contentsOf: packageURL)
                    if store.importPackage(data: packageData) {
                        imported += 1
                        while store.isBusy {
                            try? await Task.sleep(nanoseconds: 150_000_000)
                        }
                    }
                }

                defaults.set(downloadURL.absoluteString, forKey: "robo.patch.archive.url")
                defaults.set(manifest.version ?? "", forKey: "robo.patch.archive.version")

                if imported > 0 {
                    await MainActor.run {
                        store.reload()
                        syncMessage = "Patch update installed."
                    }
                }
                return
            } catch {
                continue
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
