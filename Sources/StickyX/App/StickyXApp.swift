import AppKit
import SwiftUI
import StickerXCore

@main
struct StickyXApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var model = AppModel()
  @AppStorage(AppearanceMode.storageKey) private var appearanceModeRaw = AppearanceMode.system.rawValue
  @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

  private var appearanceMode: AppearanceMode {
    AppearanceMode(rawValue: appearanceModeRaw) ?? .system
  }

  private var appLanguage: AppLanguage {
    AppLanguage(rawValue: appLanguageRaw) ?? .system
  }

  var body: some Scene {
    WindowGroup(L10n.appName(appLanguage), id: "main") {
      ContentView()
        .environmentObject(model)
        .environment(\.appLanguage, appLanguage)
        .environment(\.locale, appLanguage.locale)
        .preferredColorScheme(appearanceMode.colorScheme)
        .frame(minWidth: 900, minHeight: 620)
        .onAppear {
          appearanceMode.applyToApp()
          appDelegate.servicesProvider.model = model
          model.showRestoredDesktopNotes()
        }
        .onChange(of: appearanceModeRaw) { _, _ in
          appearanceMode.applyToApp()
        }
        .onChange(of: appLanguageRaw) { _, _ in
          model.refreshDesktopWindows()
        }
    }
    .commands {
      StickerCommands(model: model, language: appLanguage)
    }

    Settings {
      SettingsView()
        .environmentObject(model)
        .environment(\.appLanguage, appLanguage)
        .environment(\.locale, appLanguage.locale)
        .preferredColorScheme(appearanceMode.colorScheme)
        .onAppear {
          appearanceMode.applyToApp()
        }
        .onChange(of: appearanceModeRaw) { _, _ in
          appearanceMode.applyToApp()
        }
        .onChange(of: appLanguageRaw) { _, _ in
          model.refreshDesktopWindows()
        }
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  let servicesProvider = StickyServicesProvider()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    NSApp.servicesProvider = servicesProvider
    NSUpdateDynamicServices()
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }

  func application(_ application: NSApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
    false
  }

  func application(_ application: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
    false
  }
}

final class StickyServicesProvider: NSObject {
  weak var model: AppModel?

  @objc func makeStickyFromTextService(
    _ pasteboard: NSPasteboard,
    userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) {
    guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
      error.pointee = L10n.string(.serviceNoText) as NSString
      return
    }
    Task { @MainActor in
      model?.createNote(title: L10n.string(.serviceNote), plainText: text, openOnDesktop: true)
    }
  }
}
