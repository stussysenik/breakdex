import CoreData
import Foundation

// Combo+CoreDataClass.swift

@objc(Combo)
public class Combo: NSManagedObject, Identifiable {
    public var identifiableId: NSManagedObjectID { objectID }  // // use objectID as the Identifiable id since id is already declared in properties

}

// MARK: - Hashable Conformance
extension Combo {
    public override var hash: Int {
        return objectID.hashValue
    }

    public static func == (lhs: Combo, rhs: Combo) -> Bool {
        lhs.objectID == rhs.objectID
    }
}
