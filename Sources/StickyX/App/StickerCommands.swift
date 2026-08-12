import SwiftUI
import StickerXCore

struct StickerCommands: Commands {
  @ObservedObject var model: AppModel
  let language: AppLanguage

  var body: some Commands {
    CommandMenu(L10n.string(.appMenu, language: language)) {
      Button(L10n.string(.newNote, language: language)) {
        model.createNote()
      }
      .keyboardShortcut("n")

      Button(L10n.string(.insertChecklistItem, language: language)) {
        model.insertChecklistItemInCommandTarget()
      }
      .keyboardShortcut("l", modifiers: [.command, .shift])

      Divider()

      Button(L10n.string(.toggleDesktopNote, language: language)) {
        model.toggleSelectedDesktopWindow()
      }
      .keyboardShortcut("d", modifiers: [.command, .shift])
      .disabled(model.commandTargetNote == nil)

      Button(L10n.string(.floatOnTop, language: language)) {
        model.toggleSelectedFloatOnTop()
      }
      .keyboardShortcut("f", modifiers: [.command, .shift])
      .disabled(model.commandTargetNote == nil)

      Button(L10n.string(.translucent, language: language)) {
        model.toggleSelectedTranslucent()
      }
      .keyboardShortcut("t", modifiers: [.command, .shift])
      .disabled(model.commandTargetNote == nil)

      Button(L10n.string(.toggleCollapse, language: language)) {
        model.toggleSelectedCollapsed()
      }
      .keyboardShortcut("m", modifiers: [.command, .shift])
      .disabled(model.commandTargetNote == nil)

      Divider()

      Menu(L10n.string(.arrange, language: language)) {
        Button(L10n.string(.arrangeDate, language: language)) { model.arrangeDesktopNotes(by: .date) }
        Button(L10n.string(.arrangeColor, language: language)) { model.arrangeDesktopNotes(by: .color) }
        Button(L10n.string(.arrangeContent, language: language)) { model.arrangeDesktopNotes(by: .content) }
        Button(L10n.string(.arrangeScreenPosition, language: language)) { model.arrangeDesktopNotes(by: .screenPosition) }
      }

      Button(L10n.string(.print, language: language)) {
        model.printSelectedNote()
      }
      .keyboardShortcut("p")
      .disabled(model.commandTargetNote == nil)
    }

    CommandMenu(L10n.string(.colorMenu, language: language)) {
      ForEach(StickyColor.allCases) { color in
        Button(model.displayName(for: color, language: language)) {
          model.setSelectedColor(color)
        }
        .disabled(model.commandTargetNote == nil)
      }
    }

    CommandMenu(L10n.string(.formatMenu, language: language)) {
      Button(L10n.string(.showFonts, language: language)) {
        model.showFontPanel()
      }
      .keyboardShortcut("t")

      Button(L10n.string(.showColors, language: language)) {
        model.showColorPanel()
      }
      .keyboardShortcut("c", modifiers: [.command, .shift])
    }

    CommandGroup(after: .importExport) {
      Button(L10n.string(.importText, language: language)) {
        model.importText()
      }
      Button(L10n.string(.exportText, language: language)) {
        model.exportSelectedText()
      }
      .disabled(model.commandTargetNote == nil)
    }

    CommandGroup(after: .saveItem) {
      Button(L10n.string(.delete, language: language)) {
        model.deleteSelectedNote()
      }
      .keyboardShortcut(.delete)
      .disabled(model.selectedNote == nil)
    }
  }
}
