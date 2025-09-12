//
//  ComboMove+CoreDataClass.swift
//  BreakingFlashcards
//
//  Created by BreakDex Implementation
//

import Foundation
import CoreData

@objc(
    ComboMove
)
public class ComboMove: NSManagedObject, Identifiable {
    
    public var id: NSManagedObjectID {
        objectID
    }
}

// MARK: - Hashable Conformance
extension ComboMove {
    public func hash(
        into hasher: inout Hasher
    ) {
        hasher
            .combine(
                objectID
            )
    }
    
    public static func == (
        lhs: ComboMove,
        rhs: ComboMove
    ) -> Bool {
        lhs.objectID == rhs.objectID
    }
}
