import Foundation
import GRDB

public struct StickyNote: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
  public static let databaseTableName = "sticky_notes"

  public var id: String
  public var title: String
  public var bodyRTF: Data?
  public var plainText: String
  public var colorRaw: String
  public var isFavorite: Bool
  public var isDeleted: Bool
  public var isOnDesktop: Bool
  public var isFloatOnTop: Bool
  public var isTranslucent: Bool
  public var isCollapsed: Bool
  public var opacity: Double
  public var windowX: Double?
  public var windowY: Double?
  public var windowWidth: Double?
  public var windowHeight: Double?
  public var sortIndex: Int
  public var createdAt: Date
  public var updatedAt: Date
  public var deletedAt: Date?

  public var color: StickyColor {
    get { StickyColor(rawValue: colorRaw) ?? .yellow }
    set { colorRaw = newValue.rawValue }
  }

  public init(
    id: String = UUID().uuidString,
    title: String,
    bodyRTF: Data? = nil,
    plainText: String,
    color: StickyColor = .yellow,
    isFavorite: Bool = false,
    isDeleted: Bool = false,
    isOnDesktop: Bool = false,
    isFloatOnTop: Bool = false,
    isTranslucent: Bool = false,
    isCollapsed: Bool = false,
    opacity: Double = 0.92,
    windowX: Double? = nil,
    windowY: Double? = nil,
    windowWidth: Double? = nil,
    windowHeight: Double? = nil,
    sortIndex: Int = 0,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    deletedAt: Date? = nil
  ) {
    self.id = id
    self.title = title
    self.bodyRTF = bodyRTF
    self.plainText = plainText
    self.colorRaw = color.rawValue
    self.isFavorite = isFavorite
    self.isDeleted = isDeleted
    self.isOnDesktop = isOnDesktop
    self.isFloatOnTop = isFloatOnTop
    self.isTranslucent = isTranslucent
    self.isCollapsed = isCollapsed
    self.opacity = opacity
    self.windowX = windowX
    self.windowY = windowY
    self.windowWidth = windowWidth
    self.windowHeight = windowHeight
    self.sortIndex = sortIndex
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.deletedAt = deletedAt
  }
}

public enum NoteFilter: Equatable, Sendable {
  case dashboard
  case favorites
  case trash
  case color(StickyColor)
}
