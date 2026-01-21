import CoreData
import Foundation

// Move+CoreDataProperties.swift

extension Move: Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Move> {
        return NSFetchRequest<Move>(
            entityName: "Move"
        )
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?  // This is the Identifiable id
    @NSManaged public var learningState: String?
    @NSManaged public var name: String?
    @NSManaged public var photosIdentifier: String?
    @NSManaged public var rotationQuarterTurns: Int16
    @NSManaged public var tags: String?
    @NSManaged public var trimEndTime: Double
    @NSManaged public var trimStartTime: Double
    @NSManaged public var videoAssetCloudIdentifier: String?
    
    // Video editing properties
    @NSManaged public var playbackSpeed: Double       // Default: 1.0
    @NSManaged public var aspectRatioMode: String?    // "original", "1:1", "9:16", "16:9", "4:3"

    // Spaced Repetition (SM-2) properties
    @NSManaged public var easeFactor: Double          // Default: 2.5
    @NSManaged public var repetitionCount: Int16      // Default: 0
    @NSManaged public var intervalDays: Int16         // Default: 0
    @NSManaged public var nextReviewDate: Date?
    @NSManaged public var lastReviewDate: Date?
    @NSManaged public var totalReviews: Int16         // Default: 0
    @NSManaged public var lapses: Int16               // Default: 0

    @NSManaged public var combos: NSSet?
    @NSManaged public var reviews: NSSet?
}

// MARK: Generated accessors for combos
extension Move {

    @objc(
        addCombosObject:
    )
    @NSManaged public func addToCombos(
        _ value: ComboMove
    )

    @objc(
        removeCombosObject:
    )
    @NSManaged public func removeFromCombos(
        _ value: ComboMove
    )

    @objc(
        addCombos:
    )
    @NSManaged public func addToCombos(
        _ values: NSSet
    )

    @objc(
        removeCombos:
    )
    @NSManaged public func removeFromCombos(
        _ values: NSSet
    )
}

// MARK: Generated accessors for reviews
extension Move {

    @objc(
        addReviewsObject:
    )
    @NSManaged public func addToReviews(
        _ value: Review
    )

    @objc(
        removeReviewsObject:
    )
    @NSManaged public func removeFromReviews(
        _ value: Review
    )

    @objc(
        addReviews:
    )
    @NSManaged public func addToReviews(
        _ values: NSSet
    )

    @objc(
        removeReviews:
    )
    @NSManaged public func removeFromReviews(
        _ values: NSSet
    )
}