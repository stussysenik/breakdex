//
//  ComboNamingSheet.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 10/25/25.
//  Custom sheet component for combo naming with instant TextField responsiveness
//  Performance optimization: Replaces sluggish SwiftUI alert with @FocusState management
//

import SwiftUI
import OSLog

// MARK: - Combo Naming Sheet
/// Custom sheet for combo naming that eliminates TextField input lag
/// Uses @FocusState for instant keyboard management and responsiveness
struct ComboNamingSheet: View {

    // MARK: - Properties
    @Binding var isPresented: Bool
    @Binding var comboName: String
    let onSave: () -> Void
    let onCancel: () -> Void

    // MARK: - Focus Management
    @FocusState private var isTextFieldFocused: Bool

    // MARK: - State
    @State private var isInputValid = false
    @State private var showValidationFeedback = false

    // MARK: - Logger
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "📝 COMBO_NAMING_SHEET")

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Input Field
                inputSection

                // Validation Feedback
                if showValidationFeedback {
                    validationFeedbackSection
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Name Your Combo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    cancelButton
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    saveButton
                }
            }
        }
        .onAppear {
            logger.info("📝 COMBO_NAMING_SHEET: 🚀 Sheet appeared")
            // Auto-focus TextField for immediate keyboard appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
                logger.info("📝 COMBO_NAMING_SHEET: ⌨️ TextField auto-focused")
            }
        }
        .onChange(of: comboName) { _, newValue in
            validateInput(newValue)
            logger.debug("📝 COMBO_NAMING_SHEET: 📝 Input changed: '\(newValue)'")
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Enter a name for your combo")
                .font(.ibmPlexMono(size: 18, weight: .medium))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            Text("Choose a memorable name to help you identify this combo")
                .font(.ibmPlexMono(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 12) {
            TextField("e.g., Basic Six Step Combo", text: $comboName)
                .font(.ibmPlexMono(size: 16))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isTextFieldFocused ? Color.blue : Color.clear, lineWidth: 2)
                        )
                )
                .focused($isTextFieldFocused)
                .onSubmit {
                    if isInputValid {
                        saveAndClose()
                    }
                }
                .submitLabel(.done)

            // Character counter
            HStack {
                Text("\(comboName.count) characters")
                    .font(.ibmPlexMono(size: 12))
                    .foregroundColor(comboName.count > 50 ? .red : .secondary)

                Spacer()

                if comboName.count > 50 {
                    Text("Maximum 50 characters")
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - Validation Feedback Section
    private var validationFeedbackSection: some View {
        HStack(spacing: 8) {
            Image(systemName: isInputValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isInputValid ? .green : .orange)

            Text(isInputValid ? "Good to go!" : "Combo name needs at least 1 character")
                .font(.ibmPlexMono(size: 14))
                .foregroundColor(isInputValid ? .green : .orange)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isInputValid ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        )
    }

    // MARK: - Buttons
    private var cancelButton: some View {
        Button("Cancel") {
            cancelAndClose()
        }
        .font(.ibmPlexMono(size: 16, weight: .medium))
        .foregroundColor(.red)
    }

    private var saveButton: some View {
        Button("Save") {
            saveAndClose()
        }
        .font(.ibmPlexMono(size: 16, weight: .bold))
        .foregroundColor(.blue)
        .disabled(!isInputValid)
    }

    // MARK: - Input Validation
    private func validateInput(_ input: String) {
        let wasValid = isInputValid
        isInputValid = !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && input.count <= 50

        // Show validation feedback after user starts typing
        if !input.isEmpty {
            showValidationFeedback = true
        } else {
            showValidationFeedback = false
        }

        // Haptic feedback on validation state change
        if wasValid != isInputValid && !input.isEmpty {
            if isInputValid {
                HapticFeedback.notificationHaptic(.success)
                logger.info("📝 COMBO_NAMING_SHEET: ✅ Input became valid")
            } else {
                HapticFeedback.notificationHaptic(.warning)
                logger.info("📝 COMBO_NAMING_SHEET: ⚠️ Input became invalid")
            }
        }
    }

    // MARK: - Actions
    private func saveAndClose() {
        logger.info("📝 COMBO_NAMING_SHEET: 💾 Saving combo: '\(comboName)'")
        HapticFeedback.notificationHaptic(.success)
        onSave()
        isPresented = false
    }

    private func cancelAndClose() {
        logger.info("📝 COMBO_NAMING_SHEET: ❌ Cancelled naming")
        HapticFeedback.selectionHaptic()
        onCancel()
        isPresented = false
    }
}

// MARK: - Preview
#Preview("Combo Naming Sheet - Empty") {
    @State var isPresented = true
    @State var comboName = ""

    return ComboNamingSheet(
        isPresented: $isPresented,
        comboName: $comboName,
        onSave: {
            print("Saved combo: \(comboName)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}

#Preview("Combo Naming Sheet - With Text") {
    @State var isPresented = true
    @State var comboName = "My Awesome Combo"

    return ComboNamingSheet(
        isPresented: $isPresented,
        comboName: $comboName,
        onSave: {
            print("Saved combo: \(comboName)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}

#Preview("Combo Naming Sheet - Invalid (Too Long)") {
    @State var isPresented = true
    @State var comboName = String(repeating: "Very Long Combo Name ", count: 5)

    return ComboNamingSheet(
        isPresented: $isPresented,
        comboName: $comboName,
        onSave: {
            print("Saved combo: \(comboName)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}