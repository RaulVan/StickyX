import SwiftUI
import StickerXCore

enum AppLanguage: String, CaseIterable, Identifiable {
  case system
  case zhHans = "zh-Hans"
  case en

  static let storageKey = "appLanguage"

  var id: String { rawValue }

  static var current: AppLanguage {
    AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
  }

  var locale: Locale {
    Locale(identifier: resolvedIdentifier)
  }

  var resolvedIdentifier: String {
    switch self {
    case .system:
      Self.resolvedSystemIdentifier()
    case .zhHans:
      "zh-Hans"
    case .en:
      "en"
    }
  }

  static func resolvedSystemIdentifier(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
    let preferred = preferredLanguages.first?.lowercased() ?? ""
    if preferred.hasPrefix("zh") {
      return "zh-Hans"
    }
    if preferred.hasPrefix("en") {
      return "en"
    }
    return "en"
  }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
  static let defaultValue = AppLanguage.current
}

extension EnvironmentValues {
  var appLanguage: AppLanguage {
    get { self[AppLanguageEnvironmentKey.self] }
    set { self[AppLanguageEnvironmentKey.self] = newValue }
  }
}

enum L10n {
  static func isChinese(_ language: AppLanguage = .current) -> Bool {
    language.resolvedIdentifier.hasPrefix("zh")
  }

  static func appName(_ language: AppLanguage = .current) -> String {
    isChinese(language) ? "轻便笺" : "StickyX"
  }

  static func languageName(_ value: AppLanguage, language: AppLanguage = .current) -> String {
    switch value {
    case .system:
      isChinese(language) ? "跟随系统" : "Follow System"
    case .zhHans:
      isChinese(language) ? "中文" : "Chinese"
    case .en:
      "English"
    }
  }

  static func appearanceName(_ value: AppearanceMode, language: AppLanguage = .current) -> String {
    switch value {
    case .system:
      isChinese(language) ? "自动" : "Automatic"
    case .light:
      isChinese(language) ? "浅色" : "Light"
    case .dark:
      isChinese(language) ? "深色" : "Dark"
    }
  }

  static func colorName(_ value: StickyColor, language: AppLanguage = .current) -> String {
    if isChinese(language) {
      switch value {
      case .yellow: return "黄色"
      case .blue: return "蓝色"
      case .green: return "绿色"
      case .gray: return "灰色"
      case .pink: return "粉红色"
      case .purple: return "紫色"
      }
    }

    switch value {
    case .yellow: return "Yellow"
    case .blue: return "Blue"
    case .green: return "Green"
    case .gray: return "Gray"
    case .pink: return "Pink"
    case .purple: return "Purple"
    }
  }

  static func noteCount(_ count: Int, language: AppLanguage = .current) -> String {
    isChinese(language) ? "\(count) 份便笺" : "\(count) notes"
  }

  static func checklistSummary(checked: Int, total: Int, language: AppLanguage = .current) -> String {
    isChinese(language) ? "\(checked)/\(total) 已完成" : "\(checked)/\(total) completed"
  }

  static func tagCount(_ count: Int, language: AppLanguage = .current) -> String {
    isChinese(language) ? "\(count) 份" : "\(count)"
  }

  static func selectedTarget(_ title: String, language: AppLanguage = .current) -> String {
    isChinese(language) ? "当前：\(title)" : "Selected: \(title)"
  }

  static func emptyTagTitle(_ name: String, language: AppLanguage = .current) -> String {
    isChinese(language) ? "\(name)中没有便笺" : "No Notes in \(name)"
  }

  static func noteAccessibilityLabel(title: String, colorName: String, language: AppLanguage = .current) -> String {
    [title, colorName].joined(separator: isChinese(language) ? "，" : ", ")
  }

  static func accessibilityValue(
    isSelected: Bool,
    isFavorite: Bool,
    isOnDesktop: Bool,
    checklistSummary: ChecklistSummary?,
    language: AppLanguage = .current
  ) -> String {
    var parts: [String] = []
    if isSelected {
      parts.append(isChinese(language) ? "已选中" : "Selected")
    }
    if isFavorite {
      parts.append(isChinese(language) ? "已收藏" : "Favorite")
    }
    if isOnDesktop {
      parts.append(isChinese(language) ? "显示在桌面" : "On desktop")
    }
    if let checklistSummary, checklistSummary.total > 0 {
      parts.append(Self.checklistSummary(
        checked: checklistSummary.checked,
        total: checklistSummary.total,
        language: language
      ))
    }
    return parts.joined(separator: isChinese(language) ? "，" : ", ")
  }

  static func string(_ key: Key, language: AppLanguage = .current) -> String {
    let zh = isChinese(language)
    switch key {
    case .dashboard: return zh ? "全部便笺" : "Dashboard"
    case .favorites: return zh ? "收藏" : "Favorites"
    case .tags: return zh ? "标签" : "Tags"
    case .trash: return zh ? "废纸篓" : "Trash"
    case .newNote: return zh ? "新建便条" : "New Note"
    case .serviceNote: return zh ? "服务轻便笺" : "Service Sticky"
    case .searchPrompt: return zh ? "搜索便笺" : "Search notes"
    case .viewMode: return zh ? "视图" : "View"
    case .toggleGridList: return zh ? "切换网格/列表" : "Switch grid/list"
    case .operationFailed: return zh ? "操作失败" : "Action Failed"
    case .ok: return zh ? "好" : "OK"
    case .appearance: return zh ? "外观" : "Appearance"
    case .language: return zh ? "语言" : "Language"
    case .notes: return zh ? "便笺" : "Notes"
    case .defaultColor: return zh ? "默认颜色" : "Default Color"
    case .openNewNotesOnDesktop: return zh ? "新便笺默认显示到桌面" : "Open new notes on desktop"
    case .defaultTranslucent: return zh ? "新便笺默认半透明" : "Make new notes translucent"
    case .selectNote: return zh ? "选择一份便笺" : "Select a note"
    case .emptyNotesTitle: return zh ? "没有便笺" : "No Notes"
    case .emptyNotesDescription: return zh ? "创建一份便笺开始记录。" : "Create a note to start writing."
    case .noSearchResultsTitle: return zh ? "未找到便笺" : "No Results"
    case .noSearchResultsDescription: return zh ? "请尝试其他关键词。" : "Try a different search term."
    case .emptyFavoritesTitle: return zh ? "暂无收藏" : "No Favorites"
    case .emptyFavoritesDescription: return zh ? "收藏的便笺会显示在这里。" : "Favorite notes appear here."
    case .emptyTrashStateTitle: return zh ? "废纸篓为空" : "Trash is Empty"
    case .emptyTrashStateDescription: return zh ? "删除的便笺会显示在这里。" : "Deleted notes appear here."
    case .emptyTagDescription: return zh ? "在当前标签中新建一份便笺。" : "Create a note in the current tag."
    case .emptyNotePlaceholder: return zh ? "开始输入..." : "Start typing..."
    case .emptyTrashTitle: return zh ? "清空废纸篓？" : "Empty Trash?"
    case .emptyTrashMessage: return zh ? "将永久删除废纸篓中的所有便笺。" : "All notes in Trash will be permanently deleted."
    case .cancel: return zh ? "取消" : "Cancel"
    case .emptyTrash: return zh ? "清空" : "Empty"
    case .restore: return zh ? "恢复" : "Restore"
    case .permanentlyDelete: return zh ? "永久删除" : "Delete Permanently"
    case .delete: return zh ? "删除" : "Delete"
    case .favorite: return zh ? "收藏" : "Favorite"
    case .unfavorite: return zh ? "取消收藏" : "Unfavorite"
    case .pinToDesktop: return zh ? "置顶桌面" : "Pin to Desktop"
    case .hideDesktopNote: return zh ? "隐藏桌面便笺" : "Hide Desktop Note"
    case .closeDesktopNote: return zh ? "关闭桌面便笺" : "Close Desktop Note"
    case .floatOnTop: return zh ? "浮动在最前面" : "Float on Top"
    case .translucent: return zh ? "半透明" : "Translucent"
    case .expand: return zh ? "展开" : "Expand"
    case .collapse: return zh ? "折叠" : "Collapse"
    case .noteDeleted: return zh ? "便笺已删除" : "Note Deleted"
    case .renameTag: return zh ? "重命名标签" : "Rename Tag"
    case .tagName: return zh ? "标签名称" : "Tag Name"
    case .appMenu: return zh ? "轻便笺" : "StickyX"
    case .insertChecklistItem: return zh ? "插入清单项" : "Insert Checklist Item"
    case .toggleDesktopNote: return zh ? "显示/隐藏桌面便笺" : "Show/Hide Desktop Note"
    case .toggleCollapse: return zh ? "折叠/展开" : "Collapse/Expand"
    case .arrange: return zh ? "排列" : "Arrange"
    case .arrangeDate: return zh ? "按日期" : "By Date"
    case .arrangeColor: return zh ? "按颜色" : "By Color"
    case .arrangeContent: return zh ? "按内容" : "By Content"
    case .arrangeScreenPosition: return zh ? "按屏幕上的位置" : "By Screen Position"
    case .print: return zh ? "打印..." : "Print..."
    case .colorMenu: return zh ? "颜色" : "Color"
    case .tagColorMenu: return zh ? "标签颜色" : "Tag Color"
    case .formatMenu: return zh ? "格式" : "Format"
    case .showFonts: return zh ? "显示字体" : "Show Fonts"
    case .showColors: return zh ? "显示颜色" : "Show Colors"
    case .importText: return zh ? "导入文本..." : "Import Text..."
    case .exportText: return zh ? "导出文本..." : "Export Text..."
    case .serviceNoText: return zh ? "没有可用于创建便笺的文本" : "No text is available to create a note."
    }
  }

  enum Key {
    case dashboard
    case favorites
    case tags
    case trash
    case newNote
    case serviceNote
    case searchPrompt
    case viewMode
    case toggleGridList
    case operationFailed
    case ok
    case appearance
    case language
    case notes
    case defaultColor
    case openNewNotesOnDesktop
    case defaultTranslucent
    case selectNote
    case emptyNotesTitle
    case emptyNotesDescription
    case noSearchResultsTitle
    case noSearchResultsDescription
    case emptyFavoritesTitle
    case emptyFavoritesDescription
    case emptyTrashStateTitle
    case emptyTrashStateDescription
    case emptyTagDescription
    case emptyNotePlaceholder
    case emptyTrashTitle
    case emptyTrashMessage
    case cancel
    case emptyTrash
    case restore
    case permanentlyDelete
    case delete
    case favorite
    case unfavorite
    case pinToDesktop
    case hideDesktopNote
    case closeDesktopNote
    case floatOnTop
    case translucent
    case expand
    case collapse
    case noteDeleted
    case renameTag
    case tagName
    case appMenu
    case insertChecklistItem
    case toggleDesktopNote
    case toggleCollapse
    case arrange
    case arrangeDate
    case arrangeColor
    case arrangeContent
    case arrangeScreenPosition
    case print
    case colorMenu
    case tagColorMenu
    case formatMenu
    case showFonts
    case showColors
    case importText
    case exportText
    case serviceNoText
  }
}
