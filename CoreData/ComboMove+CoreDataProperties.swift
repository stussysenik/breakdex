//
//  ComboMove+CoreDataProperties.swift
//  BreakingFlashcards
//
//  Created by BreakDex Implementation
//

import Foundation
import CoreData

extension ComboMove {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ComboMove> {
        return NSFetchRequest<ComboMove>(entityName: "ComboMove")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var sequenceIndex: Int64
    @NSManaged public var combo: Combo?
    @NSManaged public var move: Move?
}