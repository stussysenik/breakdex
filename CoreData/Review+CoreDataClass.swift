import CoreData
import Foundation

// Review+CoreDataClass.swift

@objc(Review)
public class Review: NSManagedObject {

}

// MARK: - Core Data Identity Management
// Note: Core Data manages object identity internally via objectID
// NSManagedObject explicitly forbids overriding hash and isEqual methods
