import AppKit
import SwiftUI
import StickerXCore

struct RichTextEditor: NSViewRepresentable {
  @Binding var attributedText: NSAttributedString
  var backgroundColor: NSColor = .textBackgroundColor
  var onToggleChecklistLine: (Int) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    applyBackgroundColor(to: scrollView)

    // NSTextView keeps rich text editing, undo, find, links, and spell checking native on macOS.
    let textView = ChecklistTextView()
    textView.minSize = NSSize(width: 0, height: 0)
    textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
    textView.textContainer?.widthTracksTextView = true
    textView.delegate = context.coordinator
    textView.allowsUndo = true
    textView.isRichText = true
    textView.importsGraphics = true
    textView.usesFindPanel = true
    textView.isAutomaticDataDetectionEnabled = true
    textView.isAutomaticLinkDetectionEnabled = true
    textView.isContinuousSpellCheckingEnabled = true
    textView.drawsBackground = true
    textView.backgroundColor = backgroundColor
    textView.textColor = StickyColor.noteBodyNSColor
    textView.insertionPointColor = StickyColor.noteBodyNSColor
    textView.typingAttributes = StickyTextFormatter.defaultAttributes
    textView.onToggleChecklistLine = { line in
      context.coordinator.parent.onToggleChecklistLine(line)
    }
    textView.textStorage?.setAttributedString(StickyTextFormatter.normalizedChecklistMarkers(in: attributedText))

    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else { return }
    applyBackgroundColor(to: scrollView)
    let normalized = StickyTextFormatter.normalizedChecklistMarkers(in: attributedText)
    if !textView.attributedString().isEqual(to: normalized) {
      context.coordinator.isProgrammaticUpdate = true
      textView.textStorage?.setAttributedString(normalized)
      textView.typingAttributes = StickyTextFormatter.defaultAttributes
      context.coordinator.isProgrammaticUpdate = false
    }
  }

  private func applyBackgroundColor(to scrollView: NSScrollView) {
    // All three AppKit layers need the note color to avoid dark-mode system backgrounds.
    scrollView.drawsBackground = true
    scrollView.backgroundColor = backgroundColor
    scrollView.contentView.drawsBackground = true
    scrollView.contentView.backgroundColor = backgroundColor
    if let textView = scrollView.documentView as? NSTextView {
      textView.drawsBackground = true
      textView.backgroundColor = backgroundColor
    }
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: RichTextEditor
    var isProgrammaticUpdate = false

    init(_ parent: RichTextEditor) {
      self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
      guard !isProgrammaticUpdate,
            let textView = notification.object as? NSTextView else { return }
      // Push normalized user edits back to SwiftUI after native text changes.
      parent.attributedText = StickyTextFormatter.normalizedChecklistMarkers(in: textView.attributedString())
    }
  }
}

final class ChecklistTextView: NSTextView {
  var onToggleChecklistLine: ((Int) -> Void)?

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard let layoutManager,
          let textContainer else {
      super.mouseDown(with: event)
      return
    }
    let containerPoint = NSPoint(
      x: point.x - textContainerOrigin.x,
      y: point.y - textContainerOrigin.y
    )
    let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
    let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
    let nsString = string as NSString
    guard characterIndex < nsString.length else {
      super.mouseDown(with: event)
      return
    }
    let paragraphRange = nsString.paragraphRange(for: NSRange(location: characterIndex, length: 0))
    let line = nsString.substring(with: paragraphRange).trimmingCharacters(in: .newlines)
    let relativeX = containerPoint.x - layoutManager.boundingRect(forGlyphRange: paragraphRange, in: textContainer).minX
    // Treat clicks near a checklist prefix as checkbox toggles and leave normal editing elsewhere.
    if ChecklistParserAdapter.isChecklistLine(line), relativeX < 36 {
      let lineNumber = nsString.substring(to: paragraphRange.location).components(separatedBy: .newlines).count - 1
      onToggleChecklistLine?(lineNumber)
      return
    }
    super.mouseDown(with: event)
  }
}

private enum ChecklistParserAdapter {
  static func isChecklistLine(_ line: String) -> Bool {
    line.hasPrefix("☐ ")
      || line.hasPrefix("☑ ")
      || line.hasPrefix("- [ ] ")
      || line.hasPrefix("- [x] ")
      || line.hasPrefix("- [X] ")
  }
}
