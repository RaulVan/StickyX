import AppKit
import Combine
import Foundation
import StickerXCore

enum ArrangeMode {
  case date
  case color
  case content
  case screenPosition
}

@MainActor
final class AppModel: ObservableObject {
  @Published private(set) var notes: [StickyNote] = []
  @Published private(set) var colorTags: [ColorTag] = []
  @Published private(set) var colorCounts: [StickyColor: Int] = [:]
  @Published private(set) var checklistItems: [String: [ChecklistItem]] = [:]
  @Published var selectedNoteID: String?
  @Published var filter: NoteFilter = .dashboard {
    didSet { reload() }
  }
  @Published var searchText: String = "" {
    didSet { reload() }
  }
  @Published var isGridView = true
  @Published var lastError: String?

  private let database: AppDatabase?
  private let windowManager = StickyWindowManager()
  private var attributedCache: [String: NSAttributedString] = [:]

  var selectedNote: StickyNote? {
    guard let selectedNoteID else { return nil }
    return notes.first { $0.id == selectedNoteID }
  }

  init(database: AppDatabase? = try? AppDatabase()) {
    self.database = database
    do {
      try database?.seedIfNeeded()
      reload()
    } catch {
      lastError = error.localizedDescription
    }
  }

  func reload() {
    guard let database else { return }
    do {
      // Search is applied first, then narrowed by the current sidebar filter.
      let fetched = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? try database.fetchNotes(filter: filter)
        : try database.searchNotes(searchText).filter { note in matchesCurrentFilter(note) }
      colorTags = try database.fetchColorTags()
      colorCounts = try database.fetchColorCounts()
      notes = fetched
      if selectedNoteID == nil || !fetched.contains(where: { $0.id == selectedNoteID }) {
        selectedNoteID = fetched.first?.id
      }
      checklistItems = Dictionary(uniqueKeysWithValues: try fetched.map { note in
        (note.id, try database.fetchChecklistItems(noteID: note.id))
      })
      windowManager.applyVisibleState(notes: fetched, model: self)
    } catch {
      lastError = error.localizedDescription
    }
  }

  func createNote(title: String = "", plainText: String = "", color: StickyColor = .yellow, openOnDesktop: Bool = false) {
    guard let database else { return }
    do {
      let sourceFilter = filter
      let defaults = UserDefaults.standard
      let defaultColor = StickyColor(rawValue: defaults.string(forKey: "defaultColor") ?? "") ?? color
      // Creating from a color tag should keep the user in that tag and use its color.
      let noteColor: StickyColor = if case .color(let selectedColor) = sourceFilter {
        selectedColor
      } else {
        defaultColor
      }
      let shouldOpenOnDesktop = openOnDesktop || defaults.bool(forKey: "openNewNotesOnDesktop")
      let resolvedTitle = title.isEmpty ? L10n.string(.newNote) : title
      var note = try database.createNote(title: resolvedTitle, plainText: plainText, color: noteColor)
      if shouldOpenOnDesktop {
        note.isOnDesktop = true
        note.isTranslucent = defaults.bool(forKey: "defaultTranslucent")
        try database.saveNote(note)
      }
      if case .color = sourceFilter {
        filter = sourceFilter
      } else {
        filter = .dashboard
      }
      selectedNoteID = note.id
      reload()
      if shouldOpenOnDesktop {
        toggleDesktopWindow(noteID: note.id, forceOpen: true)
      }
    } catch {
      lastError = error.localizedDescription
    }
  }

  func attributedText(for note: StickyNote) -> NSAttributedString {
    if let cached = attributedCache[note.id] {
      return cached
    }
    // RTF decoding is relatively expensive and also normalizes checklist marker attributes.
    let text = StickyTextFormatter.attributedText(from: note)
    attributedCache[note.id] = text
    return text
  }

  func updateContent(noteID: String, attributedText: NSAttributedString) {
    guard let database, var note = noteByID(noteID) else { return }
    // Normalize only checklist markers so user-authored rich text styling survives saves.
    let normalized = StickyTextFormatter.normalizedChecklistMarkers(in: attributedText)
    attributedCache[noteID] = normalized
    note.bodyRTF = StickyTextFormatter.rtfData(from: normalized)
    note.plainText = normalized.string
    note.title = StickyTextFormatter.title(from: normalized.string)
    do {
      try database.saveNote(note)
      reload()
    } catch {
      lastError = error.localizedDescription
    }
  }

  func insertChecklistItemInSelectedNote() {
    guard let note = selectedNote else { return }
    insertChecklistItem(noteID: note.id)
  }

  func insertChecklistItemInCommandTarget() {
    guard let noteID = commandTargetNoteID() else { return }
    insertChecklistItem(noteID: noteID)
  }

  func insertChecklistItem(noteID: String) {
    let current = attributedText(for: noteByID(noteID) ?? StickyNote(title: L10n.string(.newNote), plainText: ""))
    let mutable = NSMutableAttributedString(attributedString: current)
    if !current.string.isEmpty && !current.string.hasSuffix("\n") {
      mutable.append(NSAttributedString(string: "\n", attributes: StickyTextFormatter.defaultAttributes))
    }
    mutable.append(NSAttributedString(string: "☐", attributes: StickyTextFormatter.checklistMarkerAttributes))
    mutable.append(NSAttributedString(string: " ", attributes: StickyTextFormatter.defaultAttributes))
    updateContent(noteID: noteID, attributedText: mutable)
  }

  func toggleChecklist(noteID: String, lineNumber: Int) {
    guard let note = noteByID(noteID) else { return }
    let mutable = NSMutableAttributedString(attributedString: attributedText(for: note))
    let nsString = mutable.string as NSString
    let lines = mutable.string.components(separatedBy: .newlines)
    guard lines.indices.contains(lineNumber) else { return }
    let oldLine = lines[lineNumber]
    let newLine = ChecklistParser.toggledLine(oldLine)
    guard oldLine != newLine else { return }
    var location = 0
    for index in 0..<lineNumber {
      location += (lines[index] as NSString).length + 1
    }
    if oldLine.hasPrefix("☐ ") || oldLine.hasPrefix("☑ ") {
      let marker = oldLine.hasPrefix("☐ ") ? "☑" : "☐"
      mutable.replaceCharacters(
        in: NSRange(location: location, length: 1),
        with: NSAttributedString(string: marker, attributes: StickyTextFormatter.checklistMarkerAttributes)
      )
      updateContent(noteID: noteID, attributedText: mutable)
      return
    }
    mutable.replaceCharacters(in: NSRange(location: location, length: nsString.substring(from: location).components(separatedBy: .newlines).first.map { ($0 as NSString).length } ?? 0), with: newLine)
    updateContent(noteID: noteID, attributedText: mutable)
  }

  func syncSelectionWithDesktopNote(noteID: String) {
    guard notes.contains(where: { $0.id == noteID }) else { return }
    selectedNoteID = noteID
  }

  func toggleSelectedDesktopWindow() {
    guard let id = selectedNoteID else { return }
    toggleDesktopWindow(noteID: id)
  }

  func openDesktopWindow(noteID: String) {
    guard let note = noteByID(noteID), !note.isDeleted else { return }
    selectedNoteID = noteID
    toggleDesktopWindow(noteID: noteID, forceOpen: true)
  }

  func toggleDesktopWindow(noteID: String, forceOpen: Bool = false) {
    guard let database, var note = noteByID(noteID) else { return }
    note.isOnDesktop = forceOpen ? true : !note.isOnDesktop
    do {
      try database.saveNote(note)
      reload()
      if note.isOnDesktop {
        windowManager.show(noteID: note.id, model: self)
      } else {
        windowManager.close(noteID: note.id)
      }
    } catch {
      lastError = error.localizedDescription
    }
  }

  func showRestoredDesktopNotes() {
    notes.filter(\.isOnDesktop).forEach { note in
      windowManager.show(noteID: note.id, model: self)
    }
  }

  func refreshDesktopWindows() {
    guard let database else { return }
    do {
      let desktopNotes = try database.fetchNotes(filter: .dashboard).filter(\.isOnDesktop)
      windowManager.applyVisibleState(notes: desktopNotes, model: self)
    } catch {
      lastError = error.localizedDescription
    }
  }

  func saveWindowFrame(noteID: String, frame: NSRect) {
    mutate(noteID: noteID) { note in
      note.windowX = frame.origin.x
      note.windowY = frame.origin.y
      note.windowWidth = frame.width
      if !note.isCollapsed {
        note.windowHeight = frame.height
      }
    }
  }

  func closeDesktopWindow(noteID: String) {
    mutate(noteID: noteID) { note in
      note.isOnDesktop = false
    }
  }

  func hideDesktopWindow(noteID: String) {
    mutate(noteID: noteID) { note in
      note.isOnDesktop = false
    }
    windowManager.close(noteID: noteID)
  }

  func toggleFavorite(noteID: String) {
    mutate(noteID: noteID) { $0.isFavorite.toggle() }
  }

  func toggleSelectedFloatOnTop() {
    guard let id = selectedNoteID else { return }
    mutate(noteID: id) { $0.isFloatOnTop.toggle() }
    if let note = noteByID(id) {
      windowManager.applyVisibleState(notes: [note], model: self)
    }
  }

  func toggleSelectedTranslucent() {
    guard let id = selectedNoteID else { return }
    mutate(noteID: id) { $0.isTranslucent.toggle() }
    if let note = noteByID(id) {
      windowManager.applyVisibleState(notes: [note], model: self)
    }
  }

  func toggleSelectedCollapsed() {
    guard let id = selectedNoteID else { return }
    toggleCollapsed(noteID: id)
  }

  func toggleCollapsed(noteID: String) {
    let currentFrame = windowManager.windowFrame(noteID: noteID)
    mutate(noteID: noteID) { note in
      if !note.isCollapsed, let currentFrame {
        // Store the expanded size before collapsing so expand restores the user's height.
        note.windowX = currentFrame.origin.x
        note.windowY = currentFrame.origin.y
        note.windowWidth = currentFrame.width
        note.windowHeight = max(currentFrame.height, StickyWindowLayout.minimumExpandedHeight)
      }
      note.isCollapsed.toggle()
    }
    if let note = noteByID(noteID) {
      windowManager.applyVisibleState(notes: [note], model: self)
    }
  }

  func setSelectedColor(_ color: StickyColor) {
    guard let id = selectedNoteID else { return }
    setColor(noteID: id, color: color)
  }

  func setColor(noteID: String, color: StickyColor) {
    mutate(noteID: noteID) { $0.color = color }
    guard let note = noteByID(noteID), note.isOnDesktop else { return }
    windowManager.applyVisibleState(notes: [note], model: self)
  }

  func displayName(for color: StickyColor, language: AppLanguage = .current) -> String {
    let storedName = colorTags.first { $0.color == color }?.name
    let defaultNames = [
      color.displayName,
      L10n.colorName(color, language: .zhHans),
      L10n.colorName(color, language: .en)
    ]
    // Default tag names follow the current language; custom names stay exactly as typed.
    if let storedName,
       !defaultNames.contains(storedName) {
      return storedName
    }
    return L10n.colorName(color, language: language)
  }

  func colorCount(for color: StickyColor) -> Int {
    colorCounts[color] ?? 0
  }

  func renameColorTag(color: StickyColor, name: String) {
    guard let database else { return }
    do {
      try database.renameColorTag(color: color, name: name)
      colorTags = try database.fetchColorTags()
    } catch {
      lastError = error.localizedDescription
    }
  }

  func deleteSelectedNote() {
    guard let database, let id = selectedNoteID else { return }
    do {
      try database.softDelete(noteID: id)
      windowManager.close(noteID: id)
      reload()
    } catch {
      lastError = error.localizedDescription
    }
  }

  func restore(noteID: String) {
    guard let database else { return }
    do {
      try database.restore(noteID: noteID)
      filter = .dashboard
      reload()
    } catch {
      lastError = error.localizedDescription
    }
  }

  func permanentlyDelete(noteID: String) {
    guard let database else { return }
    do {
      try database.permanentlyDelete(noteID: noteID)
      attributedCache.removeValue(forKey: noteID)
      windowManager.close(noteID: noteID)
      reload()
    } catch {
      lastError = error.localizedDescription
    }
  }

  func emptyTrash() {
    guard let database else { return }
    do {
      let trashIDs = try database.fetchNotes(filter: .trash).map(\.id)
      try database.emptyTrash()
      // Drop transient UI state for notes that no longer exist in SQLite.
      for noteID in trashIDs {
        attributedCache.removeValue(forKey: noteID)
        windowManager.close(noteID: noteID)
      }
      selectedNoteID = nil
      reload()
    } catch {
      lastError = error.localizedDescription
    }
  }

  func importText() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.plainText, .rtf, .rtfd]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let attributed = try StickyTextFormatter.attributedText(from: url)
      createNote(title: StickyTextFormatter.title(from: attributed.string), plainText: attributed.string)
      if let id = selectedNoteID {
        updateContent(noteID: id, attributedText: attributed)
      }
    } catch {
      lastError = error.localizedDescription
    }
  }

  func exportSelectedText() {
    guard let note = selectedNote else { return }
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "\(note.title).rtf"
    panel.allowedContentTypes = [.rtf, .rtfd, .plainText]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try StickyTextFormatter.write(attributedText(for: note), to: url)
    } catch {
      lastError = error.localizedDescription
    }
  }

  func printSelectedNote() {
    guard let note = selectedNote else { return }
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 720))
    textView.textStorage?.setAttributedString(attributedText(for: note))
    textView.isRichText = true
    let operation = NSPrintOperation(view: textView)
    operation.jobTitle = note.title
    operation.run()
  }

  func showFontPanel() {
    NSFontManager.shared.orderFrontFontPanel(nil)
  }

  func showColorPanel() {
    NSColorPanel.shared.orderFront(nil)
  }

  func arrangeDesktopNotes(by mode: ArrangeMode) {
    var visible = notes.filter { $0.isOnDesktop && !$0.isDeleted }
    switch mode {
    case .date:
      visible.sort { $0.updatedAt > $1.updatedAt }
    case .color:
      visible.sort { $0.colorRaw < $1.colorRaw }
    case .content:
      visible.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    case .screenPosition:
      visible.sort {
        (($0.windowY ?? 0), ($0.windowX ?? 0)) > (($1.windowY ?? 0), ($1.windowX ?? 0))
      }
    }
    for (index, note) in visible.enumerated() {
      let column = index % 3
      let row = index / 3
      mutate(noteID: note.id) { updated in
        updated.windowX = 720 + Double(column * 320)
        updated.windowY = 620 - Double(row * 250)
        updated.windowWidth = updated.windowWidth ?? 300
        updated.windowHeight = updated.windowHeight ?? 220
      }
      if let arranged = noteByID(note.id) {
        windowManager.show(noteID: arranged.id, model: self)
      }
    }
  }

  func noteByID(_ id: String) -> StickyNote? {
    notes.first { $0.id == id } ?? (try? database?.note(id: id)) ?? nil
  }

  private func commandTargetNoteID() -> String? {
    // Menu commands target the active desktop sticky first, then Dashboard selection.
    if let noteID = windowManager.keyDesktopNoteID(),
       let note = noteByID(noteID),
       !note.isDeleted {
      return note.id
    }
    guard let selectedNoteID,
          let note = noteByID(selectedNoteID),
          !note.isDeleted else {
      return nil
    }
    return note.id
  }

  private func mutate(noteID: String, body: (inout StickyNote) -> Void) {
    guard let database else { return }
    do {
      try database.mutate(noteID: noteID, body)
      reload()
    } catch {
      lastError = error.localizedDescription
    }
  }

  private func matchesCurrentFilter(_ note: StickyNote) -> Bool {
    switch filter {
    case .dashboard:
      !note.isDeleted
    case .favorites:
      !note.isDeleted && note.isFavorite
    case .trash:
      note.isDeleted
    case .color(let color):
      !note.isDeleted && note.color == color
    }
  }
}
