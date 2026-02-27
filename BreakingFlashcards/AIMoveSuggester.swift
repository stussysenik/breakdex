// AIMoveSuggester.swift — On-Device AI Move Name Suggester for Breakdex
//
// This file provides an on-device AI feature that suggests creative breakdancing
// move names using Apple's Foundation Models framework. When the user creates a
// new move and wants name inspiration, they tap a "Suggest" button that calls
// this module to generate a creative b-boy move name.
//
// APPLE FOUNDATION MODELS (FoundationModels framework):
//   Introduced in iOS 26.0, this framework provides access to Apple's on-device
//   language models (Apple Intelligence). Key concepts:
//
//   - SystemLanguageModel.default: The device's built-in language model.
//     `.availability` can be:
//       .available       — Model is ready to use
//       .unavailable     — Device doesn't support Apple Intelligence
//       .needsDownload   — Model needs to be downloaded first
//
//   - LanguageModelSession: A conversation session with the model.
//     Initialized with a system prompt (instructions) and then used to
//     send user messages and receive responses. The trailing closure in
//     the init is the system prompt.
//
//   - GenerationOptions: Controls generation behavior.
//     `temperature`: Controls randomness (0.0 = deterministic, 2.0 = very random).
//     We use 1.2 (high creativity) because move names should be unique and fun.
//
//   - LanguageModelSession.GenerationError: Typed errors from the model:
//     .guardrailViolation — Content was blocked by safety filters
//     .assetsUnavailable  — Model is being updated or downloaded
//
// WHY AN ENUM (NOT A CLASS):
//   This type has no stored state — it's just a namespace for static functions.
//   Using an enum with no cases (caseless enum) prevents accidental instantiation
//   while providing a clean namespace: `AIMoveSuggester.suggest()`.
//
// ARCHITECTURE ROLE:
//   AddMoveView (UI)
//     --> if AIMoveSuggester.isAvailable { ... }  (check before showing button)
//     --> let name = try await AIMoveSuggester.suggest()
//     --> Sets the move name TextField text
//
// AVAILABILITY:
//   @available(iOS 26.0, *) — This entire enum requires iOS 26.0 because the
//   FoundationModels framework doesn't exist on earlier OS versions. The call
//   site in AddMoveView uses `if #available(iOS 26.0, *)` to guard access.
//
// CONNECTED FILES:
//   - AddMoveView.swift: Calls isAvailable to show/hide the suggest button,
//     then calls suggest() when the user taps it

import Foundation
import FoundationModels

/// On-device AI move name suggester using Apple Foundation Models.
/// Requires iOS 26.0+ and Apple Intelligence enabled on the device.
///
/// This is a caseless enum (no cases) used purely as a namespace for static
/// methods. It cannot be instantiated — `AIMoveSuggester()` is a compile error.
@available(iOS 26.0, *)
enum AIMoveSuggester {

    /// Whether the on-device language model is available and ready to use.
    ///
    /// Returns true only if the device supports Apple Intelligence AND the
    /// model is downloaded and ready. Returns false if:
    /// - The device doesn't have Apple Intelligence (older hardware)
    /// - The model hasn't been downloaded yet
    /// - Apple Intelligence is disabled in Settings
    ///
    /// Used by AddMoveView to conditionally show the "Suggest" button.
    /// If this returns false, the button is hidden entirely (not just disabled).
    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// Generates a creative breakdancing move name using the on-device language model.
    ///
    /// Creates a fresh LanguageModelSession with a system prompt that instructs
    /// the model to act as a breakdancing move naming assistant. The session is
    /// created anew each call (not retained) because:
    /// 1. Each suggestion should be independent (no conversation context)
    /// 2. Sessions are lightweight to create
    /// 3. No retained state means no memory overhead when not in use
    ///
    /// SYSTEM PROMPT explains to the model:
    /// - Its role (breakdancing move naming assistant)
    /// - The constraint (1-3 words only)
    /// - The style (creative, drawing from b-boy culture)
    /// - The format (only the name, no explanation or punctuation)
    ///
    /// TEMPERATURE = 1.2:
    /// Temperature controls the randomness/creativity of the output.
    /// - 0.0: Always picks the most likely token (deterministic, boring)
    /// - 1.0: Standard balance of coherence and variety
    /// - 1.2: Higher creativity — more likely to produce unexpected combinations
    /// - 2.0: Very random (may produce nonsensical output)
    /// 1.2 is a sweet spot for creative naming — varied but still coherent.
    ///
    /// - Returns: A trimmed string containing the suggested move name (e.g., "Phantom Freeze")
    /// - Throws: LanguageModelSession.GenerationError or other errors
    ///
    /// Called from: AddMoveView's suggest button action (wrapped in a Task).
    @MainActor
    static func suggest() async throws -> String {
        // Create a new session with the system prompt.
        // The trailing closure is the system instruction that shapes the model's behavior.
        let session = LanguageModelSession {
            """
            You are a breakdancing move naming assistant. Suggest a single
            creative and catchy breakdancing move name. Keep it short (1-3 words).
            Be creative and draw from b-boy culture.
            Only respond with the move name, nothing else.
            """
        }

        // Send the user message and await the model's response.
        // This runs entirely on-device — no network request, no API key needed.
        // Generation typically takes 0.5-2 seconds depending on the device.
        let response = try await session.respond(
            to: "Suggest a unique breakdancing move name.",
            options: GenerationOptions(temperature: 1.2)  // High creativity for variety
        )

        // The response.content is the raw model output string.
        // Trim whitespace/newlines in case the model adds trailing whitespace.
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
