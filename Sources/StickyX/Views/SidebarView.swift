import SwiftUI
import StickerXCore

struct SidebarView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.appLanguage) private var appLanguage
  @State private var editingColor: StickyColor?
  @State private var draftTagName = ""

  var body: some View {
    VStack(spacing: 0) {
      List {
        Section {
          SidebarNavigationRow(
            title: L10n.string(.dashboard, language: appLanguage),
            systemImage: "note.text",
            isSelected: model.filter == .dashboard
          ) {
            model.filter = .dashboard
          }
          SidebarNavigationRow(
            title: L10n.string(.favorites, language: appLanguage),
            systemImage: "star.fill",
            isSelected: model.filter == .favorites
          ) {
            model.filter = .favorites
          }
        }

        Section(L10n.string(.tags, language: appLanguage)) {
          ForEach(StickyColor.allCases) { color in
            SidebarTagRow(
              color: color,
              name: model.displayName(for: color, language: appLanguage),
              count: model.colorCount(for: color),
              language: appLanguage,
              isSelected: selectionKey == "tag:\(color.rawValue)",
              isEditing: editingColor == color,
              draftName: $draftTagName,
              onCommit: { commitRename(color) },
              onCancel: { editingColor = nil }
            )
            .contentShape(Rectangle())
            .onTapGesture {
              // Editing a tag name keeps the current note filter stable.
              guard editingColor != color else { return }
              model.searchText = ""
              model.filter = .color(color)
            }
            .contextMenu {
              Button(L10n.string(.renameTag, language: appLanguage)) {
                editingColor = color
                draftTagName = model.displayName(for: color, language: appLanguage)
              }
            }
          }
        }
      }
      .listStyle(.sidebar)

      Divider()

      Button {
        model.filter = .trash
      } label: {
        Label(L10n.string(.trash, language: appLanguage), systemImage: "trash.fill")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(selectionKey == "trash" ? SidebarSelectionStyle.neutralBackground : Color.clear)
      }
      .accessibilityAddTraits(selectionKey == "trash" ? .isSelected : [])
    }
  }

  private var selectionKey: String {
    switch model.filter {
    case .dashboard:
      return "dashboard"
    case .favorites:
      return "favorites"
    case .trash:
      return "trash"
    case .color(let color):
      return "tag:\(color.rawValue)"
    }
  }

  private func commitRename(_ color: StickyColor) {
    model.renameColorTag(color: color, name: draftTagName)
    editingColor = nil
  }
}

private enum SidebarSelectionStyle {
  static let neutralBackground = Color.primary.opacity(0.08)
}

private struct SidebarNavigationRow: View {
  let title: String
  let systemImage: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isSelected ? SidebarSelectionStyle.neutralBackground : Color.clear)
        }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

private struct SidebarTagRow: View {
  let color: StickyColor
  let name: String
  let count: Int
  let language: AppLanguage
  let isSelected: Bool
  let isEditing: Bool
  @Binding var draftName: String
  let onCommit: () -> Void
  let onCancel: () -> Void

  @FocusState private var isTextFieldFocused: Bool

  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(color.accentColor)
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
      if isEditing {
        TextField(L10n.string(.tagName, language: language), text: $draftName)
          .textFieldStyle(.plain)
          .focused($isTextFieldFocused)
          .onSubmit(onCommit)
          .onExitCommand(perform: onCancel)
          .onAppear { isTextFieldFocused = true }
      } else {
        Text(name)
          .lineLimit(1)
      }
      Spacer(minLength: 8)
      Text(L10n.tagCount(count, language: language))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isSelected ? color.selectionStrokeColor.opacity(0.18) : Color(nsColor: .quaternaryLabelColor).opacity(0.18), in: Capsule())
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background {
      // Custom selection keeps color tags aligned with the note color system.
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(isSelected ? color.selectionBackgroundColor : Color.clear)
    }
    .help(name)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(name), \(L10n.noteCount(count, language: language))")
  }
}
