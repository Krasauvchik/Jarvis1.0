import Foundation
import SwiftUI
import Combine

// MARK: - Language Manager (in-app language switching)

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .russian: return "Русский"
        case .english: return "English"
        }
    }
    
    var flag: String {
        switch self {
        case .russian: return "🇷🇺"
        case .english: return "🇬🇧"
        }
    }
}

@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    nonisolated let objectWillChange = ObservableObjectPublisher()
    
    @AppStorage("jarvis_language") var currentLanguage: String = "ru" {
        didSet { objectWillChange.send() }
    }
    
    var language: AppLanguage {
        get { AppLanguage(rawValue: currentLanguage) ?? .russian }
        set { currentLanguage = newValue.rawValue }
    }
    
    /// Returns the localized bundle for the current language
    var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }
    
    func localizedString(_ key: String) -> String {
        let value = bundle.localizedString(forKey: key, value: nil, table: nil)
        // If no translation found, try main bundle
        if value == key {
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
        return value
    }
}
