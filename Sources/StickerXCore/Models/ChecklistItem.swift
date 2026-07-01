import Foundation
import GRDB

public struct ChecklistItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
  public static let databaseTableName = "checklist_items"

  public var id: String
  public var noteID: String
  public var lineNumber: Int
  public var text: String
  public var isChecked: Bool
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String = UUID().uuidString,
    noteID: String,
    lineNumber: Int,
    text: String,
    isChecked: Bool,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.noteID = noteID
    self.lineNumber = lineNumber
    self.text = text
    self.isChecked = isChecked
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct ChecklistSummary: Equatable, Sendable {
  public var total: Int
  public var checked: Int

  public init(total: Int, checked: Int) {
    self.total = total
    self.checked = checked
  }

  public var displayText: String {
    total == 0 ? "" : "\(checked)/\(total) done"
  }
}
