import AppKit
import Foundation
import StickerXCore
import UniformTypeIdentifiers

enum StickyTextFormatter {
  static var defaultAttributes: [NSAttributedString.Key: Any] {
    [
      .font: NSFont.systemFont(ofSize: 16),
      .foregroundColor: StickyColor.noteBodyNSColor
    ]
  }

  static var checklistMarkerAttributes: [NSAttributedString.Key: Any] {
    // Apple Symbols keeps checkbox markers consistent across pasted and imported RTF content.
    [
      .font: NSFont(name: "Apple Symbols", size: 17) ?? NSFont.systemFont(ofSize: 17),
      .foregroundColor: StickyColor.noteBodyNSColor
    ]
  }

  static func attributedText(from note: StickyNote) -> NSAttributedString {
    if let data = note.bodyRTF,
       let attributed = try? NSAttributedString(
        data: data,
        options: [.documentType: NSAttributedString.DocumentType.rtf],
        documentAttributes: nil
       ) {
      return normalizedChecklistMarkers(in: attributed)
    }
    return normalizedChecklistMarkers(in: NSAttributedString(string: note.plainText, attributes: defaultAttributes))
  }

  static func attributedText(from url: URL) throws -> NSAttributedString {
    let data = try Data(contentsOf: url)
    let ext = url.pathExtension.lowercased()
    let type: NSAttributedString.DocumentType = ext == "rtfd" ? .rtfd : (ext == "rtf" ? .rtf : .plain)
    let attributed = try NSAttributedString(
      data: data,
      options: [.documentType: type],
      documentAttributes: nil
    )
    return normalizedChecklistMarkers(in: attributed)
  }

  static func rtfData(from attributedText: NSAttributedString) -> Data? {
    let normalized = normalizedChecklistMarkers(in: attributedText)
    guard normalized.length > 0 else { return Data() }
    return try? normalized.data(
      from: NSRange(location: 0, length: normalized.length),
      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
    )
  }

  static func normalizedChecklistMarkers(in attributedText: NSAttributedString) -> NSAttributedString {
    let mutable = NSMutableAttributedString(attributedString: attributedText)
    let nsString = mutable.string as NSString
    var location = 0

    // Only rewrite the marker glyph; the rest of each line keeps the user's rich text styling.
    while location < nsString.length {
      let paragraphRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
      if paragraphRange.length >= 2 {
        let prefix = nsString.substring(with: NSRange(location: paragraphRange.location, length: 2))
        if prefix == "☐ " || prefix == "☑ " {
          mutable.addAttributes(
            checklistMarkerAttributes,
            range: NSRange(location: paragraphRange.location, length: 1)
          )
        }
      }

      let nextLocation = NSMaxRange(paragraphRange)
      if nextLocation <= location { break }
      location = nextLocation
    }

    return NSAttributedString(attributedString: mutable)
  }

  static func write(_ attributedText: NSAttributedString, to url: URL) throws {
    let ext = url.pathExtension.lowercased()
    if ext == "txt" {
      try attributedText.string.write(to: url, atomically: true, encoding: .utf8)
      return
    }
    if ext == "rtfd" {
      let wrapper = try attributedText.fileWrapper(
        from: NSRange(location: 0, length: attributedText.length),
        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
      )
      try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
      return
    }
    try rtfData(from: attributedText)?.write(to: url)
  }

  static func title(from plainText: String) -> String {
    let title = plainText
      .components(separatedBy: .newlines)
      .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
      .replacingOccurrences(of: "☐ ", with: "")
      .replacingOccurrences(of: "☑ ", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return String((title ?? L10n.string(.newNote)).prefix(40))
  }
}
