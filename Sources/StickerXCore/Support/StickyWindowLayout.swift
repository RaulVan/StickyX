import Foundation

public enum StickyWindowLayout {
  // Shared constants keep AppModel persistence and AppKit resize behavior in lockstep.
  public static let minimumWidth: Double = 220
  public static let minimumExpandedHeight: Double = 120
  public static let defaultWidth: Double = 340
  public static let defaultExpandedHeight: Double = 260
  public static let collapsedHeight: Double = 74
  public static let collapseAnimationDuration: Double = 0.18

  public static func displayHeight(isCollapsed: Bool, savedHeight: Double?) -> Double {
    if isCollapsed {
      return collapsedHeight
    }
    return max(savedHeight ?? defaultExpandedHeight, minimumExpandedHeight)
  }

  public static func displayWidth(savedWidth: Double?) -> Double {
    max(savedWidth ?? defaultWidth, minimumWidth)
  }
}
