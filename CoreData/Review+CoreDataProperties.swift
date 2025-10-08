import CoreData
import Foundation

// Review+CoreDataProperties.swift

extension Review: Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Review> {
        return NSFetchRequest<Review>(entityName: "Review")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var rating: String?
    @NSManaged public var reviewedAt: Date?
    @NSManaged public var move: Move?
}
