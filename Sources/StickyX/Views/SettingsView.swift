import SwiftUI
import StickerXCore

struct SettingsView: View {
  @Environment(\.appLanguage) private var appLanguage
  @AppStorage(AppearanceMode.storageKey) private var appearanceMode = AppearanceMode.system.rawValue
  @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
  @AppStorage("defaultColor") private var defaultColor = StickyColor.yellow.rawValue
  @AppStorage("openNewNotesOnDesktop") private var openNewNotesOnDesktop = false
  @AppStorage("defaultTranslucent") private var defaultTranslucent = false

  private let labelWidth: CGFloat = 104
  private let controlWidth: CGFloat = 268
  private let rowSpacing: CGFloat = 16

  var body: some View {
    VStack(alignment: .leading, spacing: rowSpacing) {
      settingsRow(L10n.string(.appearance, language: appLanguage)) {
        Picker(L10n.string(.appearance, language: appLanguage), selection: $appearanceMode) {
          ForEach(AppearanceMode.allCases) { mode in
            Text(L10n.appearanceName(mode, language: appLanguage)).tag(mode.rawValue)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 268, alignment: .leading)
      }

      settingsRow(L10n.string(.language, language: appLanguage)) {
        Picker(L10n.string(.language, language: appLanguage), selection: $appLanguageRaw) {
          ForEach(AppLanguage.allCases) { language in
            Text(L10n.languageName(language, language: appLanguage)).tag(language.rawValue)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: controlWidth, alignment: .leading)
      }

      settingsRow(L10n.string(.defaultColor, language: appLanguage)) {
        Picker(L10n.string(.defaultColor, language: appLanguage), selection: $defaultColor) {
          ForEach(StickyColor.allCases) { color in
            Text(L10n.colorName(color, language: appLanguage)).tag(color.rawValue)
          }
        }
        .labelsHidden()
        .frame(width: 176, alignment: .leading)
      }

      settingsRow(nil) {
        Toggle(L10n.string(.openNewNotesOnDesktop, language: appLanguage), isOn: $openNewNotesOnDesktop)
          .fixedSize(horizontal: false, vertical: true)
      }

      settingsRow(nil) {
        Toggle(L10n.string(.defaultTranslucent, language: appLanguage), isOn: $defaultTranslucent)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(width: labelWidth + 18 + controlWidth, alignment: .leading)
    .padding(.horizontal, 30)
    .padding(.vertical, 34)
    .frame(width: 450, height: 320)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private func settingsRow<Content: View>(
    _ label: String?,
    @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(alignment: .center, spacing: 18) {
      Text(label ?? "")
        .font(.body.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .frame(width: labelWidth, alignment: .trailing)
      content()
        .frame(width: controlWidth, alignment: .leading)
    }
  }
}
