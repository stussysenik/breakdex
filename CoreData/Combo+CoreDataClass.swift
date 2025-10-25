import CoreData
import Foundation

// Combo+CoreDataClass.swift

@objc(Combo)
public class Combo: NSManagedObject, Identifiable {
    public var identifiableId: NSManagedObjectID { objectID }  // use objectID as the Identifiable id since id is already declared in properties

}

// MARK: - Core Data Identity Management
// Note: Core Data manages object identity internally via objectID
// NSManagedObject explicitly forbids overriding hash and isEqual methods

// MARK: - Active Move State Management
extension Combo {

    /// Convert NSManagedObjectID to Data for storage in Core Data
    func setActiveMoveVideoReference(from objectID: NSManagedObjectID) {
        let uri = objectID.uriRepresentation()
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: uri, requiringSecureCoding: false) {
            self.activeMoveVideoReference = data
        }
    }

    /// Extract NSManagedObjectID from stored Data
    func getActiveMoveVideoReferenceObjectID() -> NSManagedObjectID? {
        guard let data = self.activeMoveVideoReference else { return nil }

        do {
            guard let uri = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: data) as? NSURL else {
                return nil
            }
            // Use the managed object context from the entity to resolve the object ID
            let coordinator = self.managedObjectContext?.persistentStoreCoordinator
            return coordinator?.managedObjectID(forURIRepresentation: uri as URL)
        } catch {
            return nil
        }
    }

    /// Store the active move's object ID for state preservation
    func setActiveMove(_ move: Move) {
        setActiveMoveVideoReference(from: move.objectID)
    }

    /// Get the active move from stored object ID
    func getActiveMove(in context: NSManagedObjectContext) -> Move? {
        guard let objectID = getActiveMoveVideoReferenceObjectID() else { return nil }

        do {
            return try context.existingObject(with: objectID) as? Move
        } catch {
            return nil
        }
    }
}
