//
//  Font+Extensions.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI

// Create an enum for your font styles.
// IMPORTANT: Use the font's PostScript name, not the file name.
enum AppFont: String {
    case bold = "IBMPlexMono-Bold"
    case regular = "IBMPlexMono-Regular"
    case thin = "IBMPlexMono-Thin"
}

// Create an extension on Font for easy access.
extension Font {
    static func appFont(_ style: AppFont, size: CGFloat) -> Font {
        return .custom(style.rawValue, size: size)
    }
}
