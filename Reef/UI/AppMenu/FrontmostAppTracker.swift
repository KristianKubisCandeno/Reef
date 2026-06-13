//
//  FrontmostAppTracker.swift
//  Reef
//
//  Tracks the frontmost application and maps it to a bound slot in the
//  current profile, so the menu bar can show a live "app number".
//

import AppKit
import Combine

@MainActor
final class FrontmostAppTracker: ObservableObject {
    @Published private(set) var frontmostSlot: Int?

    private let profileManager: ProfileManager
    private let ownBundleID: String?
    private var lastFrontmostBundleID: String?
    private var cancellables: Set<AnyCancellable> = []

    init(profileManager: ProfileManager,
         ownBundleID: String? = Bundle.main.bundleIdentifier,
         initialFrontmostBundleID: String? = NSWorkspace.shared.frontmostApplication?.bundleIdentifier) {
        self.profileManager = profileManager
        self.ownBundleID = ownBundleID

        appActivated(bundleID: initialFrontmostBundleID)

        // Re-map the current frontmost app when the active profile or its
        // bindings change — the same app can occupy a different slot.
        profileManager.$currentProfileID
            .sink { [weak self] id in self?.recompute(using: id) }
            .store(in: &cancellables)
        profileManager.$profiles
            .sink { [weak self] _ in self?.recompute(using: self?.profileManager.currentProfileID) }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            Task { @MainActor in self?.appActivated(bundleID: bundleID) }
        }
    }

    func appActivated(bundleID: String?) {
        // Ignore Reef's own activations (e.g. the cycle panel) so the icon
        // doesn't flicker while switching.
        guard let bundleID, bundleID != ownBundleID else { return }
        lastFrontmostBundleID = bundleID
        recompute(using: profileManager.currentProfileID)
    }

    private func recompute(using profileID: UUID?) {
        let profile = profileID.flatMap { id in profileManager.profiles.first { $0.id == id } }
        frontmostSlot = Self.slot(for: lastFrontmostBundleID, in: profile)
    }

    static func slot(for bundleID: String?, in profile: Profile?) -> Int? {
        guard let bundleID, let profile else { return nil }
        return profile.slot(for: bundleID)
    }
}
