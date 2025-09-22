import SwiftUI
import PhotosUI
import Foundation

// MARK: - Custom PhotosPickerItem Wrapper
/// A wrapper around SwiftUI's PhotosPickerItem to provide compatibility
/// and additional functionality for iOS 18.0 and the app's architecture
@MainActor
public class PhotosPickerItem: NSObject, ObservableObject {

    // MARK: - Properties
    private let originalItem: PhotosUI.PhotosPickerItem?
    private let customIdentifier: String?

    /// The original SwiftUI PhotosPickerItem
    public var value: PhotosUI.PhotosPickerItem? {
        return originalItem
    }

    /// The item identifier for asset loading
    public var itemIdentifier: String? {
        return customIdentifier ?? originalItem?.itemIdentifier
    }

    /// Supported content types for the item
    public var supportedContentTypes: [UTType] {
        return originalItem?.supportedContentTypes ?? []
    }

    /// Initialize with a SwiftUI PhotosPickerItem
    public init(item: PhotosUI.PhotosPickerItem) {
        self.originalItem = item
        self.customIdentifier = item.itemIdentifier
        super.init()
    }

    /// Initialize with a custom identifier (for testing/mocking)
    public init(itemIdentifier: String) {
        self.originalItem = nil
        self.customIdentifier = itemIdentifier
        super.init()
    }

    /// Initialize as an empty item
    public override init() {
        self.originalItem = nil
        self.customIdentifier = nil
        super.init()
    }

    // MARK: - Transferable Loading
    /// Load transferable content from the PhotosPicker item
    public func loadTransferable<T>(type: T.Type) async throws -> T? where T : Transferable {
        guard let originalItem = originalItem else {
            return nil
        }
        return try await originalItem.loadTransferable(type: type)
    }

    // MARK: - Key-Value Coding Support
    /// Support for value(forKey:) to maintain compatibility with existing code
    public override func value(forKey key: String) -> Any? {
        switch key {
        case "itemIdentifier":
            return itemIdentifier
        case "originalItem":
            return originalItem
        case "supportedContentTypes":
            return supportedContentTypes
        default:
            return super.value(forKey: key)
        }
    }
}