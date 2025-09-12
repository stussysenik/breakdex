//
//  Review+CoreDataProperties.swift
//  BreakingFlashcards
//
//  Created by BreakDex Implementation
//

import Foundation
import CoreData

extension Review {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Review> {
        return NSFetchRequest<Review>(entityName: "Review")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var rating: String?
    @NSManaged public var reviewedAt: Date?
    @NSManaged public var move: Move?
}