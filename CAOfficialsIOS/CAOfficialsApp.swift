//
//  CAOfficialsApp.swift
//  CA Officials
//
//  Main app entry point for CA Officials iOS app
//  Note: This file will be removed when merging into California Voters
//

import SwiftUI

@main
struct CAOfficialsApp: App {
    @StateObject private var roleManager = RoleManager()

    var body: some Scene {
        WindowGroup {
            Officials_RootView()
                .environmentObject(roleManager)
        }
    }
}
