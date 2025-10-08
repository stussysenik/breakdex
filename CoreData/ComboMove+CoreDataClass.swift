import CoreData
import Foundation

// ComboMove+CoreDataClass.swift

@objc(
    ComboMove
)
public class ComboMove: NSManagedObject {

}

// MARK: - Hashable Conformance
extension ComboMove {
    public override var hash: Int {
        return objectID.hashValue
    }

    public static func == (
        lhs: ComboMove,
        rhs: ComboMove
    ) -> Bool {
        lhs.objectID == rhs.objectID
    }
}
