//
//  GalleryHelper.swift
//  Gallery
//
//  Created by Kevin LAUNAY.
//

import Foundation

/// A utility class providing helper methods for Gallery-related tasks.
public class GalleryHelper {

    /// A helper function to create a localized string from a string key.
    /// This simplifies the process of localizing strings from the package's `.xcstrings` file.
    /// It checks the host application's bundle first, then falls back to the package's module bundle.
    /// - Parameters:
    ///   - string: The key for the localized string.
    ///   - bundle: The bundle where the `Gallery.xcstrings` file is expected to be found (usually provided by the environment).
    /// - Returns: A localized string.
    public static func stringFrom(_ string: String, bundle: Bundle) -> String {
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
    /// - Parameter bundle: The bundle to check first.
    /// - Returns: A localized string.
    public func galleryLocalized(bundle: Bundle) -> String {
        GalleryHelper.stringFrom(self, bundle: bundle)
    }
}
