//
//  Move+CoreDataClass.swift
//  BreakingFlashcards
//
//  Created by BreakDex Implementation
//

import Foundation
import CoreData

@objc(Move)
public class Move: NSManagedObject, Identifiable {

    public var id: NSManagedObjectID { objectID }

    @NSManaged public var rotationQuarterTurns: Int16

}

// MARK: - Hashable Conformance
extension Move {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectID)
    }

    public static func == (lhs: Move, rhs: Move) -> Bool {
        lhs.objectID == rhs.objectID
    }
}
