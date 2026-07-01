import Foundation
import GRDB

public struct ColorTag: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
  public static let databaseTableName = "color_tags"

  public var colorRaw: String
  public var name: String
  public var updatedAt: Date

  public var id: String { colorRaw }

  public var color: StickyColor {
    StickyColor(rawValue: colorRaw) ?? .yellow
  }

  public init(color: StickyColor, name: String? = nil, updatedAt: Date = Date()) {
    colorRaw = color.rawValue
    self.name = name ?? color.displayName
    self.updatedAt = updatedAt
  }
}
