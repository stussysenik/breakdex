//
//  Review+CoreDataClass.swift
//  BreakingFlashcards
//
//  Created by BreakDex Implementation
//

import Foundation
import CoreData

@objc(Review)
public class Review: NSManagedObject, Identifiable {

    public var id: NSManagedObjectID { objectID }
}

// MARK: - Hashable Conformance
extension Review {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectID)
    }

    public static func == (lhs: Review, rhs: Review) -> Bool {
        lhs.objectID == rhs.objectID
    }
}