//
//  Move+CoreDataProperties.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/25/25.
//
//

import Foundation
import CoreData


extension Move {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Move> {
        return NSFetchRequest<Move>(entityName: "Move")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var learningState: String?
    @NSManaged public var name: String?
    @NSManaged public var photosIdentifier: String?
    @NSManaged public var rotationQuarterTurns: Int16
    @NSManaged public var tags: String?
    @NSManaged public var trimEndTime: Double
    @NSManaged public var trimStartTime: Double
    @NSManaged public var videoAssetCloudIdentifier: String?
    @NSManaged public var combos: NSSet?
    @NSManaged public var reviews: NSSet?

}

// MARK: Generated accessors for combos
extension Move {

    @objc(addCombosObject:)
    @NSManaged public func addToCombos(_ value: ComboMove)

    @objc(removeCombosObject:)
    @NSManaged public func removeFromCombos(_ value: ComboMove)

    @objc(addCombos:)
    @NSManaged public func addToCombos(_ values: NSSet)

    @objc(removeCombos:)
    @NSManaged public func removeFromCombos(_ values: NSSet)

}

// MARK: Generated accessors for reviews
extension Move {

    @objc(addReviewsObject:)
    @NSManaged public func addToReviews(_ value: Review)

    @objc(removeReviewsObject:)
    @NSManaged public func removeFromReviews(_ value: Review)

    @objc(addReviews:)
    @NSManaged public func addToReviews(_ values: NSSet)

    @objc(removeReviews:)
    @NSManaged public func removeFromReviews(_ values: NSSet)

}

extension Move : Identifiable {

}