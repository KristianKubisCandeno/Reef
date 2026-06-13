//
//  FrontmostAppTrackerTests.swift
//  ReefTests
//

import Testing
import Foundation
@testable import Reef

@MainActor
struct FrontmostAppTrackerTests {
    private func makeManager() -> ProfileManager {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("profiles.json")
        return ProfileManager(storeURL: tmp)
    }

    @Test func boundApp_returnsSlot() {
        let pm = makeManager()
        let p = pm.currentProfile!
        pm.bind(bundleIdentifier: "com.foo.editor", to: 3, in: p)
        let tracker = FrontmostAppTracker(profileManager: pm, ownBundleID: "x.Reef", initialFrontmostBundleID: nil)
        tracker.appActivated(bundleID: "com.foo.editor")
        #expect(tracker.frontmostSlot == 3)
    }

    @Test func unboundApp_returnsNil() {
        let pm = makeManager()
        let tracker = FrontmostAppTracker(profileManager: pm, ownBundleID: "x.Reef", initialFrontmostBundleID: nil)
        tracker.appActivated(bundleID: "com.unbound.app")
        #expect(tracker.frontmostSlot == nil)
    }

    @Test func profileSwitch_recomputesSameApp() {
        let pm = makeManager()
        let a = pm.currentProfile!
        pm.bind(bundleIdentifier: "com.foo.editor", to: 3, in: a)
        let b = pm.createProfile(name: "B")
        pm.bind(bundleIdentifier: "com.foo.editor", to: 1, in: b)
        let tracker = FrontmostAppTracker(profileManager: pm, ownBundleID: "x.Reef", initialFrontmostBundleID: nil)
        tracker.appActivated(bundleID: "com.foo.editor")
        #expect(tracker.frontmostSlot == 3)
        pm.switchProfile(b)
        #expect(tracker.frontmostSlot == 1)
    }

    @Test func ownAppActivation_isIgnored() {
        let pm = makeManager()
        let p = pm.currentProfile!
        pm.bind(bundleIdentifier: "com.foo.editor", to: 3, in: p)
        let tracker = FrontmostAppTracker(profileManager: pm, ownBundleID: "x.Reef", initialFrontmostBundleID: nil)
        tracker.appActivated(bundleID: "com.foo.editor")
        tracker.appActivated(bundleID: "x.Reef")
        #expect(tracker.frontmostSlot == 3)
    }
}
