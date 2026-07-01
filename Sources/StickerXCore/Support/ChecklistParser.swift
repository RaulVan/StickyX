import Foundation

public enum ChecklistParser {
  public static func extractItems(from plainText: String, noteID: String) -> [ChecklistItem] {
    plainText
      .components(separatedBy: .newlines)
      .enumerated()
      .compactMap { index, line in
        guard let parsed = parseLine(line) else { return nil }
        return ChecklistItem(
          noteID: noteID,
          lineNumber: index,
          text: parsed.text,
          isChecked: parsed.isChecked
        )
      }
  }

  public static func summary(from items: [ChecklistItem]) -> ChecklistSummary {
    ChecklistSummary(total: items.count, checked: items.filter(\.isChecked).count)
  }

  public static func parseLine(_ line: String) -> (isChecked: Bool, text: String)? {
    // Keep both StickyX glyph markers and Markdown task-list syntax importable.
    if line.hasPrefix("☐ ") {
      return (false, String(line.dropFirst(2)))
    }
    if line.hasPrefix("☑ ") {
      return (true, String(line.dropFirst(2)))
    }
    if line.hasPrefix("- [ ] ") {
      return (false, String(line.dropFirst(6)))
    }
    if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
      return (true, String(line.dropFirst(6)))
    }
    return nil
  }

  public static func toggledPlainText(_ plainText: String, lineNumber: Int) -> String {
    var lines = plainText.components(separatedBy: .newlines)
    guard lines.indices.contains(lineNumber) else { return plainText }
    lines[lineNumber] = toggledLine(lines[lineNumber])
    return lines.joined(separator: "\n")
  }

  public static func toggledLine(_ line: String) -> String {
    if line.hasPrefix("☐ ") {
      return "☑ " + line.dropFirst(2)
    }
    if line.hasPrefix("☑ ") {
      return "☐ " + line.dropFirst(2)
    }
    if line.hasPrefix("- [ ] ") {
      return "- [x] " + line.dropFirst(6)
    }
    if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
      return "- [ ] " + line.dropFirst(6)
    }
    return line
  }

  public static func plainTextByAppendingChecklistItem(to plainText: String) -> String {
    let separator = plainText.isEmpty || plainText.hasSuffix("\n") ? "" : "\n"
    // Plain text remains the source of truth for checklist parsing and search indexing.
    return plainText + separator + "☐ "
  }
}
