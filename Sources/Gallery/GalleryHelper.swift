//
//  GalleryHelper.swift
//  Gallery
//
//  Created by Kevin LAUNAY.
//

import Foundation

/// A utility class providing helper methods for Gallery-related tasks.
class GalleryHelper {

    /// A helper function to create a localized string from a string key.
    ///
    /// This method prioritizes the provided bundle (usually the host application) and falls back
    /// to the package's internal module bundle if the translation is missing.
    ///
    /// - Parameters:
    ///   - string: The key for the localized string.
    ///   - bundle: The primary bundle to search for the translation.
    /// - Returns: The localized string if found, otherwise the key itself.
    static func stringFrom(_ string: String, bundle: Bundle) -> String {
        let requestedStr = String(localized: String.LocalizationValue(string), table: "Gallery", bundle: bundle)
        
        // If the translation matches the key and we are not already looking at the module bundle,
        // it might mean the translation is missing in the host's bundle. Try the module bundle.
        if requestedStr == string && bundle != .module {
            return String(localized: String.LocalizationValue(string), table: "Gallery", bundle: .module)
        }
        
        return requestedStr
    }
}

extension String {
    /// Localizes the string using the Gallery table with bundle fallback logic.
    ///
    /// The method first checks the provided `bundle` (typically the app's main bundle) to allow
    /// the host application to override package-default strings. If not found, it falls back
    /// to the internal `Bundle.module`.
    ///
    /// - Parameters:
    ///   - bundle: The primary bundle to check for overrides.
    ///   - defaultValue: An optional string to return if no localization is found for the key.
    /// - Returns: The localized string. Defaults to the key itself if no translation or `defaultValue` is found.
    func galleryLocalized(bundle: Bundle, defaultValue: String? = nil) -> String {
        let result = GalleryHelper.stringFrom(self, bundle: bundle)
        if result == self, let defaultValue {
            return defaultValue
        }
        return result
    }
}
