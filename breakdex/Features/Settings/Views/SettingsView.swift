//
//  SettingsView.swift
//  BreakingFlashcards
//
//  Created by Claude on 01/20/26.
//

import SwiftUI

// MARK: - Settings View
/// App settings for accessibility, data management, and information.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Accessibility Section
                accessibilitySection

                // MARK: - Data Management Section
                dataSection

                // MARK: - About Section
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.ibmPlexMono(size: 16, weight: .medium))
                }
            }
            .alert("Clear Cache?", isPresented: $viewModel.showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    viewModel.clearCache()
                }
            } message: {
                Text("This will remove cached videos and thumbnails. Your moves and combos will not be affected.")
            }
        }
    }

    // MARK: - Accessibility Section
    @ViewBuilder
    private var accessibilitySection: some View {
        Section {
            Toggle(isOn: $viewModel.largeTouchTargets) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Large Touch Targets")
                        .font(.ibmPlexMono(size: 15, weight: .medium))
                    Text("Increase button sizes for easier tapping")
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Large Touch Targets")
            .accessibilityHint("Toggle to increase button sizes")

            Toggle(isOn: $viewModel.highContrastMode) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("High Contrast")
                        .font(.ibmPlexMono(size: 15, weight: .medium))
                    Text("Increase text and UI contrast")
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("High Contrast Mode")
            .accessibilityHint("Toggle to increase visual contrast")

            Toggle(isOn: $viewModel.reduceMotion) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reduce Motion")
                        .font(.ibmPlexMono(size: 15, weight: .medium))
                    Text("Minimize animations throughout the app")
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Reduce Motion")
            .accessibilityHint("Toggle to minimize animations")
        } header: {
            Text("Accessibility")
                .font(.ibmPlexMono(size: 13, weight: .bold))
        }
    }

    // MARK: - Data Section
    @ViewBuilder
    private var dataSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cache Size")
                        .font(.ibmPlexMono(size: 15, weight: .medium))
                    Text("Cached videos and thumbnails")
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(viewModel.cacheSize)
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.secondary)
            }

            Button {
                viewModel.showClearConfirmation = true
            } label: {
                HStack {
                    Text("Clear Cache")
                        .font(.ibmPlexMono(size: 15, weight: .medium))
                        .foregroundColor(.red)
                    Spacer()
                    if viewModel.isClearing {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isClearing)
            .accessibilityLabel("Clear Cache")
            .accessibilityHint("Remove cached videos and thumbnails")

            Button {
                viewModel.resetToDefaults()
            } label: {
                Text("Reset to Defaults")
                    .font(.ibmPlexMono(size: 15, weight: .medium))
                    .foregroundColor(.orange)
            }
            .accessibilityLabel("Reset Settings")
            .accessibilityHint("Reset all settings to default values")
        } header: {
            Text("Data Management")
                .font(.ibmPlexMono(size: 13, weight: .bold))
        }
    }

    // MARK: - About Section
    @ViewBuilder
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                    .font(.ibmPlexMono(size: 15, weight: .medium))
                Spacer()
                Text(viewModel.appVersion)
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Breakdex")
                    .font(.ibmPlexMono(size: 15, weight: .bold))
                Text("Your personal breaking move library and practice companion.")
                    .font(.ibmPlexMono(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("About")
                .font(.ibmPlexMono(size: 13, weight: .bold))
        } footer: {
            Text("Made with love for the breaking community.")
                .font(.ibmPlexMono(size: 11))
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
}
