//
//  Color+Extensions.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI

extension Color {
    // Define colors from the IBM Design Language for review buttons.
    // Red 60 for "AGAIN" (Error/Danger)
    static let ibmErrorRed = Color(hex: "da1e28")
    // Orange 40 for "HARD" (Warning)
    static let ibmWarningOrange = Color(hex: "ff832b")
    // Green 50 for "GOOD" (Success)
    static let ibmSuccessGreen = Color(hex: "24a148")
}

// Helper to allow initializing Color with a hex string.
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: .alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)

        let r = Double((hexNumber & 0xff0000) >> 16) / 255
        let g = Double((hexNumber & 0x00ff00) >> 8) / 255
        let b = Double(hexNumber & 0x0000ff) / 255

        self.init(red: r, green: g, blue: b)
    }
}