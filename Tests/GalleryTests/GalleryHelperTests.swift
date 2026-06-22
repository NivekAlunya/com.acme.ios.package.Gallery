import XCTest
@testable import Gallery

final class GalleryHelperTests: XCTestCase {
    
    func testStringFromFallbackToModule() {
        // Test with a key that exists in the module but not in a dummy bundle
        let key = "gallery_loading_photos"
        let dummyBundle = Bundle(for: GalleryHelperTests.self) // This bundle won't have Gallery.xcstrings
        
        let localized = GalleryHelper.stringFrom(key, bundle: dummyBundle)
        
        // It should fall back to Bundle.module and find the English version (base)
        XCTAssertNotEqual(localized, key)
        XCTAssertEqual(localized, "Loading Photos...")
    }
    
    func testGalleryLocalizedExtension() {
        let key = "gallery_loading_image"
        let dummyBundle = Bundle(for: GalleryHelperTests.self)
        
        let localized = key.galleryLocalized(bundle: dummyBundle)
        
        XCTAssertEqual(localized, "Loading Image...")
    }
    
    func testGalleryLocalizedWithDefaultValue() {
        let key = "non_existent_key"
        let dummyBundle = Bundle(for: GalleryHelperTests.self)
        let defaultValue = "Fallback Text"
        
        // Since key doesn't exist anywhere, it should return defaultValue
        let localized = key.galleryLocalized(bundle: dummyBundle, defaultValue: defaultValue)
        
        XCTAssertEqual(localized, defaultValue)
    }

    func testGalleryLocalizedWithoutDefaultValueReturnsKey() {
        let key = "non_existent_key"
        let dummyBundle = Bundle(for: GalleryHelperTests.self)
        
        // Since key doesn't exist, it should return the key itself
        let localized = key.galleryLocalized(bundle: dummyBundle)
        
        XCTAssertEqual(localized, key)
    }
}
