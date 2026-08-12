import Foundation
import XCTest
import StickerXCore
@testable import StickyX

@MainActor
final class AppModelTests: XCTestCase {
  func testCreateNoteUsesSelectedColorFilterBeforeSettingsDefault() throws {
    let database = try makeDatabaseWithSeedNote()
    let oldDefaultColor = UserDefaults.standard.object(forKey: "defaultColor")
    defer { restoreDefaultColor(oldDefaultColor) }
    UserDefaults.standard.set(StickyColor.yellow.rawValue, forKey: "defaultColor")

    let model = AppModel(database: database)
    model.filter = .color(.purple)
    model.createNote(title: "Tagged Note")

    XCTAssertEqual(model.filter, .color(.purple))
    let note = try XCTUnwrap(model.notes.first { $0.title == "Tagged Note" })
    XCTAssertEqual(note.color, .purple)
    XCTAssertEqual(model.selectedNoteID, note.id)
  }

  func testCreateNoteUsesSettingsDefaultOutsideColorFilter() throws {
    let database = try makeDatabaseWithSeedNote()
    let oldDefaultColor = UserDefaults.standard.object(forKey: "defaultColor")
    defer { restoreDefaultColor(oldDefaultColor) }
    UserDefaults.standard.set(StickyColor.blue.rawValue, forKey: "defaultColor")

    let model = AppModel(database: database)
    model.filter = .favorites
    model.createNote(title: "Default Color Note")

    XCTAssertEqual(model.filter, .dashboard)
    let note = try XCTUnwrap(model.selectedNote)
    XCTAssertEqual(note.title, "Default Color Note")
    XCTAssertEqual(note.color, .blue)
  }

  func testSetColorByNoteIDUpdatesNoteAndCounts() throws {
    let database = try makeDatabaseWithSeedNote()
    let model = AppModel(database: database)
    let note = try XCTUnwrap(model.notes.first)

    model.setColor(noteID: note.id, color: .green)

    XCTAssertEqual(try database.note(id: note.id)?.color, .green)
    XCTAssertEqual(model.colorCount(for: .green), 1)
    XCTAssertEqual(model.colorCount(for: .yellow), 0)
  }

  func testContentUpdateRefreshesOnlyVisibleNoteStateAndChecklist() throws {
    let database = try makeDatabaseWithSeedNote()
    let model = AppModel(database: database)
    let note = try XCTUnwrap(model.notes.first)
    let content = NSAttributedString(string: "Updated title\n☐ Follow up", attributes: StickyTextFormatter.defaultAttributes)

    model.updateContent(noteID: note.id, attributedText: content)

    XCTAssertEqual(model.notes.first(where: { $0.id == note.id })?.title, "Updated title")
    XCTAssertEqual(model.checklistItems[note.id]?.count, 1)
    XCTAssertEqual(try database.note(id: note.id)?.plainText, content.string)
  }

  func testContentUpdateRemovesNoteThatNoLongerMatchesSearch() throws {
    let database = try makeDatabaseWithSeedNote()
    let model = AppModel(database: database)
    let note = try XCTUnwrap(model.notes.first)
    model.searchText = "Seed"
    XCTAssertEqual(model.notes.map(\.id), [note.id])

    model.updateContent(
      noteID: note.id,
      attributedText: NSAttributedString(string: "Different content", attributes: StickyTextFormatter.defaultAttributes)
    )

    XCTAssertTrue(model.notes.isEmpty)
  }

  private func makeDatabaseWithSeedNote() throws -> AppDatabase {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let database = try AppDatabase(path: directory.appendingPathComponent("test.sqlite").path)
    _ = try database.createNote(title: "Seed", plainText: "Seed", color: .yellow)
    return database
  }

  private func restoreDefaultColor(_ value: Any?) {
    if let value {
      UserDefaults.standard.set(value, forKey: "defaultColor")
    } else {
      UserDefaults.standard.removeObject(forKey: "defaultColor")
    }
  }
}
