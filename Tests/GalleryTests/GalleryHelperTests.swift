import Testing
import Foundation
@testable import Gallery

private final class BundleToken {}

@Suite("GalleryHelper Tests")
struct GalleryHelperTests {
    
    @Test("String fallback to module when key is missing in custom bundle")
    func testStringFromFallbackToModule() {
        // Test with a key that exists in the module but not in a dummy bundle
        let key = "gallery_loading_photos"
        let dummyBundle = Bundle(for: BundleToken.self)
        
        let localized = GalleryHelper.stringFrom(key, bundle: dummyBundle)
        
        // It should fall back to Bundle.module and find the English version (base)
        #expect(localized != key)
        #expect(localized == "Loading Photos...")
    }
    
    @Test("Gallery localized extension finds string")
    func testGalleryLocalizedExtension() {
        let key = "gallery_loading_image"
        let dummyBundle = Bundle(for: BundleToken.self)
        
        let localized = key.galleryLocalized(bundle: dummyBundle)
        
        #expect(localized == "Loading Image...")
    }
    
    @Test("Gallery localized with default fallback value")
    func testGalleryLocalizedWithDefaultValue() {
        let key = "non_existent_key"
        let dummyBundle = Bundle(for: BundleToken.self)
        let defaultValue = "Fallback Text"
        
        // Since key doesn't exist anywhere, it should return defaultValue
        let localized = key.galleryLocalized(bundle: dummyBundle, defaultValue: defaultValue)
        
        #expect(localized == defaultValue)
    }

    @Test("Gallery localized without default value returns key itself")
    func testGalleryLocalizedWithoutDefaultValueReturnsKey() {
        let key = "non_existent_key"
        let dummyBundle = Bundle(for: BundleToken.self)
        
        // Since key doesn't exist, it should return the key itself
        let localized = key.galleryLocalized(bundle: dummyBundle)
        
        #expect(localized == key)
    }
}
