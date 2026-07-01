import SwiftUI
import StickerXCore

struct ContentView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.appLanguage) private var appLanguage
  @State private var columnVisibility = NavigationSplitViewVisibility.all
  @State private var isConfirmingEmptyTrash = false

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      SidebarView()
        .navigationSplitViewColumnWidth(min: 210, ideal: 240)
    } detail: {
      DashboardView()
    }
    .navigationTitle(toolbarTitle)
    .searchable(text: $model.searchText, placement: .toolbar, prompt: Text(L10n.string(.searchPrompt, language: appLanguage)))
    .toolbar {
      ToolbarItemGroup {
        Button {
          model.createNote()
        } label: {
          Label(L10n.string(.newNote, language: appLanguage), systemImage: "square.and.pencil")
        }
        .help(L10n.string(.newNote, language: appLanguage))

        Picker(L10n.string(.viewMode, language: appLanguage), selection: $model.isGridView) {
          Image(systemName: "square.grid.2x2").tag(true)
          Image(systemName: "list.bullet").tag(false)
        }
        .pickerStyle(.segmented)
        .frame(width: 88)
        .help(L10n.string(.toggleGridList, language: appLanguage))

        if model.filter == .trash {
          Button(role: .destructive) {
            isConfirmingEmptyTrash = true
          } label: {
            Label(L10n.string(.emptyTrash, language: appLanguage), systemImage: "trash")
          }
          .disabled(model.notes.isEmpty)
        }
      }
    }
    .alert(L10n.string(.emptyTrashTitle, language: appLanguage), isPresented: $isConfirmingEmptyTrash) {
      Button(L10n.string(.cancel, language: appLanguage), role: .cancel) {}
      Button(L10n.string(.emptyTrash, language: appLanguage), role: .destructive) {
        model.emptyTrash()
      }
    } message: {
      Text(L10n.string(.emptyTrashMessage, language: appLanguage))
    }
    .alert(L10n.string(.operationFailed, language: appLanguage), isPresented: Binding(
      get: { model.lastError != nil },
      set: { if !$0 { model.lastError = nil } }
    )) {
      Button(L10n.string(.ok, language: appLanguage)) { model.lastError = nil }
    } message: {
      Text(model.lastError ?? "")
    }
  }

  private var filterTitle: String {
    switch model.filter {
    case .dashboard:
      L10n.string(.dashboard, language: appLanguage)
    case .favorites:
      L10n.string(.favorites, language: appLanguage)
    case .trash:
      L10n.string(.trash, language: appLanguage)
    case .color(let color):
      model.displayName(for: color, language: appLanguage)
    }
  }

  private var toolbarTitle: String {
    "\(L10n.appName(appLanguage)) · \(filterTitle) \(L10n.noteCount(model.notes.count, language: appLanguage))"
  }
}
