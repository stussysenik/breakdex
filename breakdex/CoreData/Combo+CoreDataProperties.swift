import CoreData
import Foundation

// Combo+CoreDataProperties.swift

extension Combo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Combo> {
        return NSFetchRequest<Combo>(
            entityName: "Combo"
        )
    }

    @NSManaged public var activeMoveVideoReference: Data?
    @NSManaged public var id: UUID?  // This is the Identifiable id
    @NSManaged public var name: String?
    @NSManaged public var comboMoves: NSSet?
}

// MARK: Generated accessors for comboMoves
extension Combo {

    @objc(
        addComboMovesObject:
    )
    @NSManaged public func addToComboMoves(
        _ value: ComboMove
    )

    @objc(
        removeComboMovesObject:
    )
    @NSManaged public func removeFromComboMoves(
        _ value: ComboMove
    )

    @objc(
        addComboMoves:
    )
    @NSManaged public func addToComboMoves(
        _ values: NSSet
    )

    @objc(
        removeComboMoves:
    )
    @NSManaged public func removeFromComboMoves(
        _ values: NSSet
    )
}
