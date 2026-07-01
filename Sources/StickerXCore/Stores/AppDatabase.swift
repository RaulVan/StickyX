import Foundation
import GRDB

public final class AppDatabase {
  public let dbQueue: DatabaseQueue

  public init(path: String? = nil) throws {
    let databasePath = try path ?? Self.defaultDatabasePath()
    try FileManager.default.createDirectory(
      atPath: (databasePath as NSString).deletingLastPathComponent,
      withIntermediateDirectories: true
    )
    dbQueue = try DatabaseQueue(path: databasePath)
    try Self.migrator.migrate(dbQueue)
  }

  public static func defaultDatabasePath() throws -> String {
    let baseURL = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let databaseURL = baseURL
      .appendingPathComponent("StickyX", isDirectory: true)
      .appendingPathComponent("StickyX.sqlite")
    let legacyURL = baseURL
      .appendingPathComponent("StickerX", isDirectory: true)
      .appendingPathComponent("StickerX.sqlite")
    // Preserve existing local data from the early StickerX bundle name.
    try migrateLegacyDatabaseIfNeeded(from: legacyURL, to: databaseURL)
    return databaseURL.path
  }

  public func seedIfNeeded() throws {
    try dbQueue.write { db in
      let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sticky_notes") ?? 0
      guard count == 0 else { return }
      let samples = Self.sampleNotes()
      for var note in samples {
        note.sortIndex = samples.firstIndex(where: { $0.id == note.id }) ?? 0
        try note.insert(db)
        try Self.refreshFTS(db, note: note)
        try Self.replaceChecklistItems(db, noteID: note.id, plainText: note.plainText)
      }
    }
  }

  public func fetchNotes(filter: NoteFilter = .dashboard) throws -> [StickyNote] {
    try dbQueue.read { db in
      switch filter {
      case .dashboard:
        return try StickyNote.fetchAll(
          db,
          sql: "SELECT * FROM sticky_notes WHERE isDeleted = 0 ORDER BY sortIndex ASC, updatedAt DESC"
        )
      case .favorites:
        return try StickyNote.fetchAll(
          db,
          sql: "SELECT * FROM sticky_notes WHERE isDeleted = 0 AND isFavorite = 1 ORDER BY updatedAt DESC"
        )
      case .trash:
        return try StickyNote.fetchAll(
          db,
          sql: "SELECT * FROM sticky_notes WHERE isDeleted = 1 ORDER BY deletedAt DESC"
        )
      case .color(let color):
        return try StickyNote.fetchAll(
          db,
          sql: "SELECT * FROM sticky_notes WHERE isDeleted = 0 AND colorRaw = ? ORDER BY updatedAt DESC",
          arguments: [color.rawValue]
        )
      }
    }
  }

  public func searchNotes(_ rawQuery: String) throws -> [StickyNote] {
    let query = Self.ftsQuery(rawQuery)
    guard !query.isEmpty else { return try fetchNotes() }
    return try dbQueue.read { db in
      try StickyNote.fetchAll(
        db,
        sql: """
        SELECT n.* FROM sticky_notes n
        JOIN sticky_notes_fts ON sticky_notes_fts.id = n.id
        WHERE sticky_notes_fts MATCH ? AND n.isDeleted = 0
        ORDER BY n.updatedAt DESC
        """,
        arguments: [query]
      )
    }
  }

  public func fetchChecklistItems(noteID: String) throws -> [ChecklistItem] {
    try dbQueue.read { db in
      try ChecklistItem.fetchAll(
        db,
        sql: "SELECT * FROM checklist_items WHERE noteID = ? ORDER BY lineNumber ASC",
        arguments: [noteID]
      )
    }
  }

  public func fetchColorTags() throws -> [ColorTag] {
    try dbQueue.read { db in
      let tags = try ColorTag.fetchAll(db)
      let tagsByColor = Dictionary(uniqueKeysWithValues: tags.map { ($0.colorRaw, $0) })
      return StickyColor.allCases.map { color in
        tagsByColor[color.rawValue] ?? ColorTag(color: color)
      }
    }
  }

  public func fetchColorCounts() throws -> [StickyColor: Int] {
    try dbQueue.read { db in
      let rows = try Row.fetchAll(
        db,
        sql: "SELECT colorRaw, COUNT(*) AS count FROM sticky_notes WHERE isDeleted = 0 GROUP BY colorRaw"
      )
      let rawCounts = Dictionary(uniqueKeysWithValues: rows.map { row -> (String, Int) in
        let colorRaw: String = row["colorRaw"]
        let count: Int = row["count"]
        return (colorRaw, count)
      })
      return Dictionary(uniqueKeysWithValues: StickyColor.allCases.map { color in
        (color, rawCounts[color.rawValue] ?? 0)
      })
    }
  }

  public func renameColorTag(color: StickyColor, name rawName: String) throws {
    let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedName = trimmedName.isEmpty ? color.displayName : trimmedName
    try dbQueue.write { db in
      try db.execute(
        sql: """
        INSERT INTO color_tags(colorRaw, name, updatedAt) VALUES (?, ?, ?)
        ON CONFLICT(colorRaw) DO UPDATE SET name = excluded.name, updatedAt = excluded.updatedAt
        """,
        arguments: [color.rawValue, resolvedName, Date()]
      )
    }
  }

  public func createNote(title: String, plainText: String, color: StickyColor = .yellow) throws -> StickyNote {
    try dbQueue.write { db in
      var note = StickyNote(
        title: title.isEmpty ? Self.derivedTitle(from: plainText) : title,
        plainText: plainText,
        color: color,
        sortIndex: (try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sortIndex), 0) + 1 FROM sticky_notes") ?? 0)
      )
      note.updatedAt = Date()
      try note.insert(db)
      try Self.refreshFTS(db, note: note)
      try Self.replaceChecklistItems(db, noteID: note.id, plainText: note.plainText)
      return note
    }
  }

  public func saveNote(_ note: StickyNote) throws {
    try dbQueue.write { db in
      var updated = note
      updated.updatedAt = Date()
      updated.title = updated.title.isEmpty ? Self.derivedTitle(from: updated.plainText) : updated.title
      try updated.save(db)
      try Self.refreshFTS(db, note: updated)
      try Self.replaceChecklistItems(db, noteID: updated.id, plainText: updated.plainText)
    }
  }

  public func note(id: String) throws -> StickyNote? {
    try dbQueue.read { db in
      try StickyNote.fetchOne(db, sql: "SELECT * FROM sticky_notes WHERE id = ?", arguments: [id])
    }
  }

  public func softDelete(noteID: String) throws {
    try mutate(noteID: noteID) { note in
      note.isDeleted = true
      note.isOnDesktop = false
      note.deletedAt = Date()
    }
  }

  public func restore(noteID: String) throws {
    try mutate(noteID: noteID) { note in
      note.isDeleted = false
      note.deletedAt = nil
    }
  }

  public func permanentlyDelete(noteID: String) throws {
    try dbQueue.write { db in
      _ = try StickyNote.deleteOne(db, key: noteID)
      try db.execute(sql: "DELETE FROM sticky_notes_fts WHERE id = ?", arguments: [noteID])
      try db.execute(sql: "DELETE FROM checklist_items WHERE noteID = ?", arguments: [noteID])
    }
  }

  public func emptyTrash() throws {
    try dbQueue.write { db in
      let noteIDs = try String.fetchAll(db, sql: "SELECT id FROM sticky_notes WHERE isDeleted = 1")
      for noteID in noteIDs {
        // FTS5 rows require explicit deletion because SQLite cascades skip virtual tables.
        _ = try StickyNote.deleteOne(db, key: noteID)
        try db.execute(sql: "DELETE FROM sticky_notes_fts WHERE id = ?", arguments: [noteID])
        try db.execute(sql: "DELETE FROM checklist_items WHERE noteID = ?", arguments: [noteID])
      }
    }
  }

  public func toggleChecklistLine(noteID: String, lineNumber: Int) throws -> StickyNote? {
    try dbQueue.write { db in
      guard var note = try StickyNote.fetchOne(db, key: noteID) else { return nil }
      note.plainText = ChecklistParser.toggledPlainText(note.plainText, lineNumber: lineNumber)
      note.bodyRTF = nil
      note.updatedAt = Date()
      try note.save(db)
      try Self.refreshFTS(db, note: note)
      try Self.replaceChecklistItems(db, noteID: note.id, plainText: note.plainText)
      return note
    }
  }

  public func mutate(noteID: String, _ body: (inout StickyNote) throws -> Void) throws {
    try dbQueue.write { db in
      guard var note = try StickyNote.fetchOne(db, key: noteID) else { return }
      try body(&note)
      note.updatedAt = Date()
      try note.save(db)
      // Keep denormalized search and checklist tables in sync with every note mutation.
      try Self.refreshFTS(db, note: note)
      try Self.replaceChecklistItems(db, noteID: note.id, plainText: note.plainText)
    }
  }
}

private extension AppDatabase {
  static func migrateLegacyDatabaseIfNeeded(from legacyURL: URL, to databaseURL: URL) throws {
    let fileManager = FileManager.default
    guard
      fileManager.fileExists(atPath: legacyURL.path),
      !fileManager.fileExists(atPath: databaseURL.path)
    else {
      return
    }

    try fileManager.createDirectory(
      at: databaseURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try fileManager.copyItem(at: legacyURL, to: databaseURL)

    // Copy WAL/SHM siblings with the main database so uncheckpointed writes are retained.
    for suffix in ["-wal", "-shm"] {
      let sourceURL = URL(fileURLWithPath: legacyURL.path + suffix)
      let destinationURL = URL(fileURLWithPath: databaseURL.path + suffix)
      guard
        fileManager.fileExists(atPath: sourceURL.path),
        !fileManager.fileExists(atPath: destinationURL.path)
      else {
        continue
      }
      try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }
  }

  static var migrator: DatabaseMigrator {
    var migrator = DatabaseMigrator()
    // v1 owns the note lifecycle, checklist projection, and FTS index used by search.
    migrator.registerMigration("v1") { db in
      try db.execute(sql: """
      CREATE TABLE sticky_notes (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        bodyRTF BLOB,
        plainText TEXT NOT NULL,
        colorRaw TEXT NOT NULL,
        isFavorite BOOLEAN NOT NULL DEFAULT 0,
        isDeleted BOOLEAN NOT NULL DEFAULT 0,
        isOnDesktop BOOLEAN NOT NULL DEFAULT 0,
        isFloatOnTop BOOLEAN NOT NULL DEFAULT 0,
        isTranslucent BOOLEAN NOT NULL DEFAULT 0,
        isCollapsed BOOLEAN NOT NULL DEFAULT 0,
        opacity DOUBLE NOT NULL DEFAULT 0.92,
        windowX DOUBLE,
        windowY DOUBLE,
        windowWidth DOUBLE,
        windowHeight DOUBLE,
        sortIndex INTEGER NOT NULL DEFAULT 0,
        createdAt DATETIME NOT NULL,
        updatedAt DATETIME NOT NULL,
        deletedAt DATETIME
      );

      CREATE TABLE checklist_items (
        id TEXT PRIMARY KEY NOT NULL,
        noteID TEXT NOT NULL REFERENCES sticky_notes(id) ON DELETE CASCADE,
        lineNumber INTEGER NOT NULL,
        text TEXT NOT NULL,
        isChecked BOOLEAN NOT NULL DEFAULT 0,
        createdAt DATETIME NOT NULL,
        updatedAt DATETIME NOT NULL
      );

      CREATE INDEX idx_sticky_notes_deleted_updated ON sticky_notes(isDeleted, updatedAt);
      CREATE INDEX idx_sticky_notes_color ON sticky_notes(colorRaw);
      CREATE INDEX idx_checklist_items_note ON checklist_items(noteID, lineNumber);
      CREATE VIRTUAL TABLE sticky_notes_fts USING fts5(id UNINDEXED, title, plainText);
      """)
    }
    // Color tags are display names for StickyColor values; notes continue to store colorRaw.
    migrator.registerMigration("v2_color_tags") { db in
      try db.execute(sql: """
      CREATE TABLE color_tags (
        colorRaw TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        updatedAt DATETIME NOT NULL
      );
      """)

      for color in StickyColor.allCases {
        try db.execute(
          sql: "INSERT INTO color_tags(colorRaw, name, updatedAt) VALUES (?, ?, ?)",
          arguments: [color.rawValue, color.displayName, Date()]
        )
      }
    }
    return migrator
  }

  static func refreshFTS(_ db: Database, note: StickyNote) throws {
    try db.execute(sql: "DELETE FROM sticky_notes_fts WHERE id = ?", arguments: [note.id])
    // Deleted notes stay hidden from full-text search while remaining visible in Trash.
    guard !note.isDeleted else { return }
    try db.execute(
      sql: "INSERT INTO sticky_notes_fts(id, title, plainText) VALUES (?, ?, ?)",
      arguments: [note.id, note.title, note.plainText]
    )
  }

  static func replaceChecklistItems(_ db: Database, noteID: String, plainText: String) throws {
    // Checklist items are a query-friendly projection of plainText, rebuilt on each save.
    try db.execute(sql: "DELETE FROM checklist_items WHERE noteID = ?", arguments: [noteID])
    for item in ChecklistParser.extractItems(from: plainText, noteID: noteID) {
      try item.insert(db)
    }
  }

  static func ftsQuery(_ rawQuery: String) -> String {
    // Prefix tokens keep short note searches useful with generated escaped FTS syntax.
    rawQuery
      .split { !$0.isLetter && !$0.isNumber }
      .map { token in
        let escaped = token.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\"*"
      }
      .joined(separator: " ")
  }

  static func derivedTitle(from plainText: String) -> String {
    let first = plainText
      .components(separatedBy: .newlines)
      .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
      .replacingOccurrences(of: "☐ ", with: "")
      .replacingOccurrences(of: "☑ ", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return String((first ?? "新建便条").prefix(40))
  }

  static func sampleNotes() -> [StickyNote] {
    [
      StickyNote(
        title: "Wish List",
        plainText: "Animal Crossing + another switch controller\nPS5\nCaptain America's shield\nApple Watch?",
        color: .blue,
        isOnDesktop: true,
        windowX: 820,
        windowY: 540,
        windowWidth: 280,
        windowHeight: 220
      ),
      StickyNote(
        title: "Dogs I want",
        plainText: "Siberian Husky\nBoarder Collie\nAustralian Shepherd !\n\nNames: Ghost, Wolf, Chaos, Echo, Bandit, Atlas, Scout",
        color: .yellow,
        isOnDesktop: true,
        windowX: 1120,
        windowY: 540,
        windowWidth: 280,
        windowHeight: 230
      ),
      StickyNote(
        title: "Albums to buy",
        plainText: "☐ AJR - Neotheater\n☐ Milky Chance - Mind The Moon\n☑ COIN - Dreamland\n☐ BRONSON?\n☐ Madeon - Good Faith\n☐ Surfaces - Horizons",
        color: .green,
        isOnDesktop: true,
        isFloatOnTop: true,
        windowX: 820,
        windowY: 170,
        windowWidth: 590,
        windowHeight: 360
      ),
      StickyNote(
        title: "CSS/JS Tricks",
        plainText: "[https://css-tricks.com/styling-links-with-real-underlines/]\n[https://css-tricks.com/ghost-buttons-with-directional-awareness-in-css/]",
        color: .gray
      ),
      StickyNote(
        title: "random",
        plainText: "☐ Add native window controls\n☐ Finish import/export\n☑ Pick app icon",
        color: .pink
      )
    ]
  }
}
