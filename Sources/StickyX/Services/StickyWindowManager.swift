import AppKit
import SwiftUI
import StickerXCore

@MainActor
final class StickyWindowManager {
  private var windows: [String: NSWindow] = [:]
  private var delegates: [String: StickyWindowDelegate] = [:]
  private var windowLanguages: [String: AppLanguage] = [:]
  private var programmaticFrameUpdateNoteIDs = Set<String>()
  private var frameUpdateTokens: [String: UUID] = [:]

  func show(noteID: String, model: AppModel) {
    guard let note = model.noteByID(noteID) else { return }
    if let window = windows[noteID] {
      configure(window, with: note, model: model)
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let frame = frame(for: note)
    // Borderless windows remove the AppKit title chrome while still allowing custom SwiftUI controls.
    let window = StickyPanelWindow(
      contentRect: frame,
      styleMask: [.borderless, .resizable],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    window.hasShadow = true
    window.contentView = hostingView(noteID: noteID, model: model)
    windowLanguages[noteID] = AppLanguage.current
    window.title = note.title
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.backgroundColor = .clear
    window.isOpaque = false
    window.collectionBehavior = [.managed, .fullScreenAuxiliary]
    hideStandardWindowControls(window)
    configure(window, with: note, model: model)

    let delegate = StickyWindowDelegate(noteID: noteID, model: model, windowManager: self)
    window.delegate = delegate
    delegates[noteID] = delegate
    windows[noteID] = window
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func close(noteID: String) {
    // Keep the NSWindow alive; AppKit close animations can outlive SwiftUI state updates.
    windows[noteID]?.orderOut(nil)
  }

  func keyDesktopNoteID() -> String? {
    guard let keyWindow = NSApp.keyWindow else { return nil }
    // Command handlers use the key desktop sticky as the active editing target.
    return windows.first { _, window in
      window === keyWindow
    }?.key
  }

  func windowFrame(noteID: String) -> NSRect? {
    windows[noteID]?.frame
  }

  func isProgrammaticFrameUpdate(noteID: String) -> Bool {
    programmaticFrameUpdateNoteIDs.contains(noteID)
  }

  func applyVisibleState(notes: [StickyNote], model: AppModel) {
    for note in notes where note.isOnDesktop {
      if let window = windows[note.id] {
        configure(window, with: note, model: model)
      }
    }
  }

  private func configure(_ window: NSWindow, with note: StickyNote, model: AppModel) {
    window.level = note.isFloatOnTop ? .floating : .normal
    window.alphaValue = note.isTranslucent ? note.opacity : 1.0
    window.title = note.title
    if windowLanguages[note.id] != AppLanguage.current {
      window.contentView = hostingView(noteID: note.id, model: model)
      windowLanguages[note.id] = AppLanguage.current
    }
    hideStandardWindowControls(window)

    window.minSize = NSSize(
      width: StickyWindowLayout.minimumWidth,
      height: StickyWindowLayout.collapsedHeight
    )
    let targetSize = frame(for: note).size
    if window.frame.size != targetSize {
      let noteID = note.id
      let updateToken = UUID()
      // Suppress delegate frame writes during our own collapse/expand animation.
      programmaticFrameUpdateNoteIDs.insert(noteID)
      frameUpdateTokens[noteID] = updateToken
      DispatchQueue.main.async { [weak self, weak window] in
        guard let self else { return }
        guard let window else {
          self.finishProgrammaticFrameUpdate(noteID: noteID, token: updateToken)
          return
        }
        var frame = window.frame
        let oldMaxY = frame.maxY
        frame.size = targetSize
        frame.origin.y = oldMaxY - frame.height
        let finalFrame = frame
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
          window.setFrame(finalFrame, display: true, animate: false)
          model.saveWindowFrame(noteID: noteID, frame: finalFrame)
          window.invalidateShadow()
          self.finishProgrammaticFrameUpdate(noteID: noteID, token: updateToken)
          return
        }

        NSAnimationContext.runAnimationGroup { context in
          context.duration = StickyWindowLayout.collapseAnimationDuration
          context.allowsImplicitAnimation = true
          window.animator().setFrame(finalFrame, display: true)
        } completionHandler: { [weak self] in
          Task { @MainActor in
            model.saveWindowFrame(noteID: noteID, frame: finalFrame)
            window.invalidateShadow()
            self?.finishProgrammaticFrameUpdate(noteID: noteID, token: updateToken)
          }
        }
      }
    }
  }

  private func finishProgrammaticFrameUpdate(noteID: String, token: UUID) {
    guard frameUpdateTokens[noteID] == token else { return }
    frameUpdateTokens.removeValue(forKey: noteID)
    programmaticFrameUpdateNoteIDs.remove(noteID)
  }

  private func frame(for note: StickyNote) -> NSRect {
    if let x = note.windowX,
       let y = note.windowY,
       let width = note.windowWidth,
       let height = note.windowHeight {
      // Collapsed windows use a fixed height but keep the saved expanded height for restore.
      return NSRect(
        x: x,
        y: y,
        width: StickyWindowLayout.displayWidth(savedWidth: width),
        height: StickyWindowLayout.displayHeight(isCollapsed: note.isCollapsed, savedHeight: height)
      )
    }
    let offset = Double(windows.count * 28)
    return NSRect(
      x: 720 + offset,
      y: 360 - offset,
      width: StickyWindowLayout.defaultWidth,
      height: StickyWindowLayout.displayHeight(isCollapsed: note.isCollapsed, savedHeight: nil)
    )
  }

  private func hideStandardWindowControls(_ window: NSWindow) {
    [
      NSWindow.ButtonType.closeButton,
      .miniaturizeButton,
      .zoomButton
    ].forEach { buttonType in
      let button = window.standardWindowButton(buttonType)
      button?.isHidden = true
      button?.isEnabled = false
    }
  }

  private func hostingView(noteID: String, model: AppModel) -> NSHostingView<AnyView> {
    let language = AppLanguage.current
    let view = DesktopStickyWindowView(noteID: noteID)
      .environmentObject(model)
      .environment(\.appLanguage, language)
      .environment(\.locale, language.locale)
    let hostingView = NSHostingView(rootView: AnyView(view))
    hostingView.wantsLayer = true
    hostingView.layer?.backgroundColor = NSColor.clear.cgColor
    // Layer clipping keeps resize animations rounded even while AppKit resizes the window.
    hostingView.layer?.cornerRadius = 12
    hostingView.layer?.cornerCurve = .continuous
    hostingView.layer?.masksToBounds = true
    return hostingView
  }
}

@MainActor
private final class StickyPanelWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

@MainActor
private final class StickyWindowDelegate: NSObject, NSWindowDelegate {
  let noteID: String
  weak var model: AppModel?
  weak var windowManager: StickyWindowManager?

  init(noteID: String, model: AppModel, windowManager: StickyWindowManager) {
    self.noteID = noteID
    self.model = model
    self.windowManager = windowManager
  }

  func windowDidMove(_ notification: Notification) {
    saveFrame(notification)
  }

  func windowDidResize(_ notification: Notification) {
    saveFrame(notification)
  }

  func windowDidBecomeKey(_ notification: Notification) {
    // Keep Dashboard selection aligned with the desktop note currently being edited.
    model?.syncSelectionWithDesktopNote(noteID: noteID)
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    model?.closeDesktopWindow(noteID: noteID)
    sender.orderOut(nil)
    return false
  }

  private func saveFrame(_ notification: Notification) {
    guard let window = notification.object as? NSWindow else { return }
    // User-driven moves/resizes are persisted; programmatic animations are handled by configure().
    guard windowManager?.isProgrammaticFrameUpdate(noteID: noteID) != true else { return }
    model?.saveWindowFrame(noteID: noteID, frame: window.frame)
  }
}
