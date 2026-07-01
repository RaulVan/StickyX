import AppKit
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  static let storageKey = "appearanceMode"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .system: "自动"
    case .light: "浅色"
    case .dark: "深色"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }

  @MainActor
  func applyToApp() {
    switch self {
    case .system:
      NSApp.appearance = nil
    case .light:
      NSApp.appearance = NSAppearance(named: .aqua)
    case .dark:
      NSApp.appearance = NSAppearance(named: .darkAqua)
    }
  }
}
