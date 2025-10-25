import CoreData
import Foundation

// ComboMove+CoreDataClass.swift

@objc(
    ComboMove
)
public class ComboMove: NSManagedObject {

}

// MARK: - Core Data Identity Management
// Note: Core Data manages object identity internally via objectID
// NSManagedObject explicitly forbids overriding hash and isEqual methods
