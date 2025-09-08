//
//  Combo+CoreDataClass.swift
//  BreakingFlashcards
//
//  Created by BreakDex Implementation
//

import Foundation
import CoreData

@objc(Combo)
public class Combo: NSManagedObject, Identifiable {

    public var id: NSManagedObjectID { objectID }

}

// MARK: - Hashable Conformance
extension Combo {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectID)
    }

    public static func == (lhs: Combo, rhs: Combo) -> Bool {
        lhs.objectID == rhs.objectID
    }
}
