import SwiftUI
import StickerXCore

struct DashboardView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.appLanguage) private var appLanguage

  private let columns = [
    GridItem(.adaptive(minimum: 230, maximum: 280), spacing: 24)
  ]

  var body: some View {
    VStack(spacing: 0) {
      if model.notes.isEmpty {
        emptyState
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if model.isGridView {
        ScrollViewReader { proxy in
          ScrollView {
            Color.clear
              .frame(height: 1)
              .id(DashboardScrollTarget.top)
            LazyVGrid(columns: columns, spacing: 24) {
              ForEach(model.notes) { note in
                StickyCard(note: note)
              }
            }
            .padding(.horizontal, 28)
            .padding(.top, 30)
            .padding(.bottom, 28)
          }
          .onAppear { scrollToTop(proxy) }
          .onChange(of: model.filter) { _, _ in scrollToTop(proxy) }
          .onChange(of: model.searchText) { _, _ in scrollToTop(proxy) }
        }
      } else {
        ScrollViewReader { proxy in
          List(model.notes) { note in
            StickyListRow(note: note)
              .id(note.id)
          }
          .listStyle(.inset)
          .onAppear { scrollToTop(proxy) }
          .onChange(of: model.filter) { _, _ in scrollToTop(proxy) }
          .onChange(of: model.searchText) { _, _ in scrollToTop(proxy) }
        }
      }
    }
    .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label(emptyStateTitle, systemImage: emptyStateSystemImage)
    } description: {
      Text(emptyStateDescription)
    } actions: {
      if canCreateFromEmptyState {
        Button {
          model.createNote()
        } label: {
          Label(L10n.string(.newNote, language: appLanguage), systemImage: "square.and.pencil")
        }
      }
    }
  }

  private var emptyStateTitle: String {
    if hasSearchQuery {
      return L10n.string(.noSearchResultsTitle, language: appLanguage)
    }
    switch model.filter {
    case .dashboard:
      return L10n.string(.emptyNotesTitle, language: appLanguage)
    case .favorites:
      return L10n.string(.emptyFavoritesTitle, language: appLanguage)
    case .trash:
      return L10n.string(.emptyTrashStateTitle, language: appLanguage)
    case .color(let color):
      return L10n.emptyTagTitle(model.displayName(for: color, language: appLanguage), language: appLanguage)
    }
  }

  private var emptyStateDescription: String {
    if hasSearchQuery {
      return L10n.string(.noSearchResultsDescription, language: appLanguage)
    }
    switch model.filter {
    case .dashboard:
      return L10n.string(.emptyNotesDescription, language: appLanguage)
    case .favorites:
      return L10n.string(.emptyFavoritesDescription, language: appLanguage)
    case .trash:
      return L10n.string(.emptyTrashStateDescription, language: appLanguage)
    case .color:
      return L10n.string(.emptyTagDescription, language: appLanguage)
    }
  }

  private var emptyStateSystemImage: String {
    if hasSearchQuery { return "magnifyingglass" }
    switch model.filter {
    case .dashboard: return "note.text"
    case .favorites: return "star"
    case .trash: return "trash"
    case .color: return "tag"
    }
  }

  private var canCreateFromEmptyState: Bool {
    guard !hasSearchQuery else { return false }
    switch model.filter {
    case .dashboard, .color:
      return true
    case .favorites, .trash:
      return false
    }
  }

  private var hasSearchQuery: Bool {
    !model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func scrollToTop(_ proxy: ScrollViewProxy) {
    DispatchQueue.main.async {
      // Filter and search changes should start at the first result, matching Finder-like lists.
      withAnimation(.easeOut(duration: 0.16)) {
        if model.isGridView {
          proxy.scrollTo(DashboardScrollTarget.top, anchor: .top)
        } else if let firstID = model.notes.first?.id {
          proxy.scrollTo(firstID, anchor: .top)
        }
      }
    }
  }
}

struct StickyCard: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.appLanguage) private var appLanguage
  let note: StickyNote

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(note.title)
          .font(.headline)
          .lineLimit(1)
          .foregroundStyle(StickyColor.noteTitleTextColor)
        Spacer()
        Button {
          model.toggleFavorite(noteID: note.id)
        } label: {
          Image(systemName: note.isFavorite ? "star.fill" : "star")
        }
        .buttonStyle(.plain)
        .foregroundStyle(StickyColor.noteTitleTextColor)
        .help(note.isFavorite ? L10n.string(.unfavorite, language: appLanguage) : L10n.string(.favorite, language: appLanguage))
        .accessibilityLabel(note.isFavorite ? L10n.string(.unfavorite, language: appLanguage) : L10n.string(.favorite, language: appLanguage))
      }
      .padding(.horizontal, 16)
      .frame(height: 44)
      .background(note.color.accentColor)

      VStack(alignment: .leading, spacing: 10) {
        checklistPreview
        if note.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(L10n.string(.emptyNotePlaceholder, language: appLanguage))
            .font(.system(size: 14))
            .foregroundStyle(StickyColor.noteSecondaryTextColor.opacity(0.72))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          Text(note.plainText)
            .font(.system(size: 14))
            .foregroundStyle(StickyColor.noteBodyTextColor)
            .lineLimit(7)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Spacer(minLength: 0)
      }
      .padding(16)
      .frame(height: 170, alignment: .top)
      .background(note.color.noteBackground)
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(model.selectedNoteID == note.id ? note.color.selectionStrokeColor : Color.clear, lineWidth: 2)
    }
    .onTapGesture {
      model.selectedNoteID = note.id
    }
    // Keep single-click selection immediate while double-click opens the desktop sticky.
    .simultaneousGesture(TapGesture(count: 2).onEnded {
      model.openDesktopWindow(noteID: note.id)
    })
    .contextMenu {
      if note.isDeleted {
        Button(L10n.string(.restore, language: appLanguage)) { model.restore(noteID: note.id) }
        Button(L10n.string(.permanentlyDelete, language: appLanguage), role: .destructive) { model.permanentlyDelete(noteID: note.id) }
      } else {
        Button(note.isOnDesktop ? L10n.string(.hideDesktopNote, language: appLanguage) : L10n.string(.pinToDesktop, language: appLanguage)) {
          model.toggleDesktopWindow(noteID: note.id)
        }
        Button(note.isFavorite ? L10n.string(.unfavorite, language: appLanguage) : L10n.string(.favorite, language: appLanguage)) {
          model.toggleFavorite(noteID: note.id)
        }
        NoteColorMenu(noteID: note.id, selectedColor: note.color)
        Divider()
        Button(L10n.string(.delete, language: appLanguage), role: .destructive) {
          model.selectedNoteID = note.id
          model.deleteSelectedNote()
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(L10n.noteAccessibilityLabel(
      title: note.title,
      colorName: model.displayName(for: note.color, language: appLanguage),
      language: appLanguage
    ))
    .accessibilityValue(accessibilityValue)
  }

  private var checklistPreview: some View {
    let items = model.checklistItems[note.id] ?? []
    let summary = ChecklistParser.summary(from: items)
    return Group {
      if summary.total > 0 {
        HStack(spacing: 8) {
          Image(systemName: "checklist")
          Text(L10n.checklistSummary(checked: summary.checked, total: summary.total, language: appLanguage))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(StickyColor.noteSecondaryTextColor)
      }
    }
  }

  private var accessibilityValue: String {
    let summary = ChecklistParser.summary(from: model.checklistItems[note.id] ?? [])
    return L10n.accessibilityValue(
      isSelected: model.selectedNoteID == note.id,
      isFavorite: note.isFavorite,
      isOnDesktop: note.isOnDesktop,
      checklistSummary: summary.total > 0 ? summary : nil,
      language: appLanguage
    )
  }
}

struct StickyListRow: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.appLanguage) private var appLanguage
  let note: StickyNote

  private var isSelected: Bool {
    model.selectedNoteID == note.id
  }

  var body: some View {
    HStack(spacing: 12) {
      RoundedRectangle(cornerRadius: 4)
        .fill(note.color.accentColor)
        .frame(width: 14, height: 36)
      VStack(alignment: .leading) {
        Text(note.title)
          .font(.headline)
        Text(note.plainText)
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      if note.isOnDesktop {
        Image(systemName: "macwindow.on.rectangle")
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(isSelected ? note.color.selectionBackgroundColor : Color.clear)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(isSelected ? note.color.selectionStrokeColor : Color.clear, lineWidth: 2)
    }
    .contentShape(Rectangle())
    .onTapGesture {
      model.selectedNoteID = note.id
    }
    // The list row mirrors card behavior so both Dashboard modes share the same muscle memory.
    .simultaneousGesture(TapGesture(count: 2).onEnded {
      model.openDesktopWindow(noteID: note.id)
    })
    .contextMenu {
      if note.isDeleted {
        Button(L10n.string(.restore, language: appLanguage)) { model.restore(noteID: note.id) }
        Button(L10n.string(.permanentlyDelete, language: appLanguage), role: .destructive) { model.permanentlyDelete(noteID: note.id) }
      } else {
        Button(note.isOnDesktop ? L10n.string(.hideDesktopNote, language: appLanguage) : L10n.string(.pinToDesktop, language: appLanguage)) {
          model.toggleDesktopWindow(noteID: note.id)
        }
        Button(note.isFavorite ? L10n.string(.unfavorite, language: appLanguage) : L10n.string(.favorite, language: appLanguage)) {
          model.toggleFavorite(noteID: note.id)
        }
        NoteColorMenu(noteID: note.id, selectedColor: note.color)
        Divider()
        Button(L10n.string(.delete, language: appLanguage), role: .destructive) {
          model.selectedNoteID = note.id
          model.deleteSelectedNote()
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(L10n.noteAccessibilityLabel(
      title: note.title,
      colorName: model.displayName(for: note.color, language: appLanguage),
      language: appLanguage
    ))
    .accessibilityValue(L10n.accessibilityValue(
      isSelected: model.selectedNoteID == note.id,
      isFavorite: note.isFavorite,
      isOnDesktop: note.isOnDesktop,
      checklistSummary: nil,
      language: appLanguage
    ))
  }
}

private struct NoteColorMenu: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.appLanguage) private var appLanguage
  let noteID: String
  let selectedColor: StickyColor

  var body: some View {
    Menu(L10n.string(.tagColorMenu, language: appLanguage)) {
      ForEach(StickyColor.allCases) { color in
        Button {
          model.setColor(noteID: noteID, color: color)
        } label: {
          if color == selectedColor {
            Label(model.displayName(for: color, language: appLanguage), systemImage: "checkmark")
          } else {
            Text(model.displayName(for: color, language: appLanguage))
          }
        }
      }
    }
  }
}

private enum DashboardScrollTarget {
  static let top = "dashboardTop"
}
