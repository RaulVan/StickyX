import SwiftUI
import StickerXCore

struct DesktopStickyWindowView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.appLanguage) private var appLanguage
  let noteID: String

  var body: some View {
    if let note = model.noteByID(noteID) {
      VStack(spacing: 0) {
        header(note)
        if !note.isCollapsed {
          // Collapse and expand are driven solely by the NSWindow frame animation.
          RichTextEditor(
            attributedText: Binding(
              get: { model.attributedText(for: note) },
              set: { model.updateContent(noteID: note.id, attributedText: $0) }
            ),
            backgroundColor: note.color.noteBackgroundNSColor,
            onToggleChecklistLine: { line in
              model.toggleChecklist(noteID: note.id, lineNumber: line)
            }
          )
          .background(note.color.noteBackground)
        }
      }
      .background(note.color.noteBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    } else {
      Text(L10n.string(.noteDeleted, language: appLanguage))
        .frame(width: 240, height: 120)
    }
  }

  private func header(_ note: StickyNote) -> some View {
    HStack(spacing: 4) {
      Text(note.title)
        .font(.headline)
        .lineLimit(1)
      Spacer()
      headerButton(
        systemName: "xmark",
        help: L10n.string(.closeDesktopNote, language: appLanguage)
      ) {
        model.hideDesktopWindow(noteID: note.id)
      }

      headerButton(
        systemName: note.isFloatOnTop ? "pin.fill" : "pin",
        help: L10n.string(.floatOnTop, language: appLanguage)
      ) {
        model.selectedNoteID = note.id
        model.toggleSelectedFloatOnTop()
      }

      headerButton(
        systemName: note.isTranslucent ? "circle.lefthalf.filled" : "circle",
        help: L10n.string(.translucent, language: appLanguage)
      ) {
        model.selectedNoteID = note.id
        model.toggleSelectedTranslucent()
      }

      headerButton(
        systemName: note.isCollapsed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
        help: note.isCollapsed ? L10n.string(.expand, language: appLanguage) : L10n.string(.collapse, language: appLanguage)
      ) {
        model.toggleCollapsed(noteID: note.id)
      }
    }
    .foregroundStyle(StickyColor.noteTitleTextColor)
    .padding(.horizontal, 14)
    .frame(height: 42)
    .background(note.color.accentColor)
  }

  private func headerButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 14, weight: .regular))
        .foregroundStyle(StickyColor.noteTitleTextColor.opacity(0.86))
        // Keep a comfortable hit target while drawing a quieter symbol.
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(help)
    .accessibilityLabel(help)
  }
}
