import Foundation
import XCTest
@testable import StickerXCore

final class AppDatabaseTests: XCTestCase {
  func testCreateFetchSearchAndDeleteLifecycle() throws {
    let database = try makeDatabase()
    let note = try database.createNote(
      title: "Launch",
      plainText: "☐ Ship first build\n☑ Pick icon",
      color: .green
    )

    let all = try database.fetchNotes()
    XCTAssertEqual(all.count, 1)
    XCTAssertEqual(all.first?.title, "Launch")

    let search = try database.searchNotes("Ship")
    XCTAssertEqual(search.map(\.id), [note.id])

    try database.softDelete(noteID: note.id)
    XCTAssertTrue(try database.fetchNotes().isEmpty)
    XCTAssertEqual(try database.fetchNotes(filter: .trash).count, 1)

    try database.restore(noteID: note.id)
    XCTAssertEqual(try database.fetchNotes().count, 1)

    try database.permanentlyDelete(noteID: note.id)
    XCTAssertTrue(try database.fetchNotes().isEmpty)
  }

  func testChecklistExtractionAndToggle() throws {
    let database = try makeDatabase()
    let note = try database.createNote(
      title: "Checklist",
      plainText: "☐ Write PRD\n☑ Generate icon\nPlain line",
      color: .yellow
    )

    var items = try database.fetchChecklistItems(noteID: note.id)
    XCTAssertEqual(items.count, 2)
    XCTAssertEqual(items[0].text, "Write PRD")
    XCTAssertFalse(items[0].isChecked)
    XCTAssertTrue(items[1].isChecked)

    let updated = try XCTUnwrap(database.toggleChecklistLine(noteID: note.id, lineNumber: 0))
    XCTAssertTrue(updated.plainText.hasPrefix("☑ Write PRD"))

    items = try database.fetchChecklistItems(noteID: note.id)
    XCTAssertTrue(items[0].isChecked)
    XCTAssertEqual(ChecklistParser.summary(from: items), ChecklistSummary(total: 2, checked: 2))
  }

  func testColorAndFavoriteFilters() throws {
    let database = try makeDatabase()
    let green = try database.createNote(title: "Green", plainText: "one", color: .green)
    _ = try database.createNote(title: "Blue", plainText: "two", color: .blue)
    try database.mutate(noteID: green.id) { note in
      note.isFavorite = true
    }

    XCTAssertEqual(try database.fetchNotes(filter: .color(.green)).map(\.id), [green.id])
    XCTAssertEqual(try database.fetchNotes(filter: .favorites).map(\.id), [green.id])
  }

  func testColorTagsCanBeRenamedWithoutChangingColorFiltering() throws {
    let database = try makeDatabase()
    let tags = try database.fetchColorTags()
    XCTAssertEqual(tags.count, StickyColor.allCases.count)
    XCTAssertEqual(tags.first { $0.color == .blue }?.name, "蓝色")

    try database.renameColorTag(color: .blue, name: "工作")
    let renamedTags = try database.fetchColorTags()
    XCTAssertEqual(renamedTags.first { $0.color == .blue }?.name, "工作")

    let blue = try database.createNote(title: "Blue", plainText: "one", color: .blue)
    _ = try database.createNote(title: "Green", plainText: "two", color: .green)
    XCTAssertEqual(try database.fetchNotes(filter: .color(.blue)).map(\.id), [blue.id])
    XCTAssertEqual(try database.fetchColorCounts()[.blue], 1)
  }

  func testColorCountsOnlyIncludeActiveNotes() throws {
    let database = try makeDatabase()
    _ = try database.createNote(title: "Blue Active", plainText: "one", color: .blue)
    let deletedBlue = try database.createNote(title: "Blue Deleted", plainText: "two", color: .blue)
    _ = try database.createNote(title: "Green Active", plainText: "three", color: .green)

    try database.softDelete(noteID: deletedBlue.id)

    let counts = try database.fetchColorCounts()
    XCTAssertEqual(counts[.blue], 1)
    XCTAssertEqual(counts[.green], 1)
    XCTAssertEqual(counts[.yellow], 0)
  }

  func testEmptyTrashDeletesDeletedNotesAndKeepsActiveNotes() throws {
    let database = try makeDatabase()
    let active = try database.createNote(title: "Active", plainText: "Keep", color: .yellow)
    let deletedWithChecklist = try database.createNote(title: "Trash A", plainText: "☐ Remove", color: .blue)
    let deletedPlain = try database.createNote(title: "Trash B", plainText: "Remove plain", color: .green)

    try database.softDelete(noteID: deletedWithChecklist.id)
    try database.softDelete(noteID: deletedPlain.id)
    try database.emptyTrash()

    XCTAssertEqual(try database.fetchNotes().map(\.id), [active.id])
    XCTAssertTrue(try database.fetchNotes(filter: .trash).isEmpty)
    XCTAssertTrue(try database.fetchChecklistItems(noteID: deletedWithChecklist.id).isEmpty)
    XCTAssertTrue(try database.searchNotes("Remove").isEmpty)
  }

  func testWindowLayoutKeepsExpandedHeightWhenCollapsed() {
    XCTAssertEqual(StickyWindowLayout.displayHeight(isCollapsed: true, savedHeight: 360), 74)
    XCTAssertEqual(StickyWindowLayout.displayHeight(isCollapsed: false, savedHeight: 360), 360)
    XCTAssertEqual(StickyWindowLayout.displayHeight(isCollapsed: false, savedHeight: 80), 120)
    XCTAssertEqual(StickyWindowLayout.displayWidth(savedWidth: 180), 220)
  }

  private func makeDatabase() throws -> AppDatabase {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return try AppDatabase(path: directory.appendingPathComponent("test.sqlite").path)
  }
}
