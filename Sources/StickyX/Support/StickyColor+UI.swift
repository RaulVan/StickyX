import AppKit
import SwiftUI
import StickerXCore

extension StickyColor {
  static var noteTitleTextColor: Color {
    Color(red: 0.12, green: 0.13, blue: 0.14)
  }

  static var noteBodyTextColor: Color {
    Color(red: 0.15, green: 0.15, blue: 0.16)
  }

  static var noteSecondaryTextColor: Color {
    Color(red: 0.36, green: 0.37, blue: 0.38)
  }

  static var noteBodyNSColor: NSColor {
    NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.16, alpha: 1)
  }

  var accentColor: Color {
    switch self {
    case .yellow: Color(red: 1.0, green: 0.93, blue: 0.36)
    case .blue: Color(red: 0.62, green: 0.92, blue: 0.96)
    case .green: Color(red: 0.60, green: 0.94, blue: 0.55)
    case .gray: Color(red: 0.82, green: 0.82, blue: 0.80)
    case .pink: Color(red: 0.96, green: 0.58, blue: 0.58)
    case .purple: Color(red: 0.75, green: 0.65, blue: 0.95)
    }
  }

  var noteBackground: Color {
    switch self {
    case .yellow: Color(red: 1.0, green: 0.98, blue: 0.84)
    case .blue: Color(red: 0.90, green: 0.98, blue: 1.0)
    case .green: Color(red: 0.91, green: 1.0, blue: 0.89)
    case .gray: Color(red: 0.95, green: 0.95, blue: 0.93)
    case .pink: Color(red: 1.0, green: 0.90, blue: 0.90)
    case .purple: Color(red: 0.94, green: 0.91, blue: 1.0)
    }
  }

  var noteBackgroundNSColor: NSColor {
    switch self {
    case .yellow: NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.84, alpha: 1)
    case .blue: NSColor(calibratedRed: 0.90, green: 0.98, blue: 1.0, alpha: 1)
    case .green: NSColor(calibratedRed: 0.91, green: 1.0, blue: 0.89, alpha: 1)
    case .gray: NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.93, alpha: 1)
    case .pink: NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.90, alpha: 1)
    case .purple: NSColor(calibratedRed: 0.94, green: 0.91, blue: 1.0, alpha: 1)
    }
  }

  var selectionStrokeColor: Color {
    switch self {
    case .yellow: Color(red: 0.80, green: 0.61, blue: 0.12)
    case .blue: Color(red: 0.30, green: 0.63, blue: 0.68)
    case .green: Color(red: 0.34, green: 0.66, blue: 0.30)
    case .gray: Color(red: 0.52, green: 0.53, blue: 0.50)
    case .pink: Color(red: 0.72, green: 0.36, blue: 0.38)
    case .purple: Color(red: 0.52, green: 0.43, blue: 0.76)
    }
  }

  var selectionBackgroundColor: Color {
    selectionStrokeColor.opacity(0.12)
  }
}
