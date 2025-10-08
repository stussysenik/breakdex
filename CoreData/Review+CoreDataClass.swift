import CoreData
import Foundation

// Review+CoreDataClass.swift

@objc(Review)
public class Review: NSManagedObject {

}

// MARK: - Hashable Conformance
extension Review {
    public override var hash: Int {
        return objectID.hashValue
    }

    public static func == (lhs: Review, rhs: Review) -> Bool {
        lhs.objectID == rhs.objectID
    }
}
