import AppKit
import Foundation
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private var popover: NSPopover?
  private var ipcServer: IPCServer?
  private var discord: DiscordRPC?
  private var menuController: MenuBarController?
  private var iinaMonitorTimer: Timer?

  private enum LogColor: String {
    case reset = "\u{001B}[0m"
    case cyan = "\u{001B}[36m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case magenta = "\u{001B}[35m"
    case red = "\u{001B}[31m"
  }

  private func colorize(_ message: String, color: LogColor) -> String {
    return "\(color.rawValue)\(message)\(LogColor.reset.rawValue)"
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    menuController = MenuBarController()
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    popover = NSPopover()
    popover?.behavior = .transient
    popover?.contentViewController = NSHostingController(
      rootView: MenuBarView(controller: menuController!))
    if let button = statusItem?.button {
      button.image = NSImage(
        systemSymbolName: "play.rectangle.fill", accessibilityDescription: "IINAcord")
      button.action = #selector(togglePopover(_:))
      button.target = self
    }
    discord = DiscordRPC()
    discord?.onLog = { message in
      let formatted = self.colorize("[IINAcord][Discord] \(message)", color: .cyan)
      print(formatted)
      self.menuController?.debugMessage = message
    }
    ipcServer = IPCServer(path: "/tmp/iinacord.sock")
    ipcServer?.onLog = { message in
      let formatted = self.colorize("[IINAcord][IPC] \(message)", color: .green)
      print(formatted)
      DispatchQueue.main.async {
        self.menuController?.socketStatus = message
        self.menuController?.debugMessage = message
      }
    }
    ipcServer?.onMessage = { [weak self] (msg: IPCMessage) in
      guard let s = self else { return }
      let currentTitle = msg.title ?? "<nil>"
      print("[IINAcord][IPC] received message \(msg)")
      print("[IINAcord][IPC] current IINA title = \(currentTitle)")
      if let state = PlaybackState(from: msg) {
        s.menuController?.isIINAConnected = true
        print("[IINAcord][IPC] decoded playback state title = \(state.title)")
        s.discord?.update(with: state)
      }
    }
    print(colorize("[IINAcord] starting IPC server at /tmp/iinacord.sock", color: .yellow))
    ipcServer?.start()
    print(colorize("[IINAcord] starting Discord monitor", color: .yellow))
    discord?.startMonitoring { [weak self] (connected: Bool) in
      DispatchQueue.main.async {
        self?.menuController?.isDiscordConnected = connected
      }
      if connected, self?.isIINAApplicationRunning() == true {
        self?.discord?.showPlaceholderActivityIfNeeded()
      }
    }
    startIINAMonitor()
  }

  @objc private func togglePopover(_ sender: Any?) {
    guard let popover = popover, let statusItem = statusItem else { return }
    if popover.isShown {
      popover.performClose(sender)
    } else if let button = statusItem.button {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    ipcServer?.stop()
    discord?.stop()
    iinaMonitorTimer?.invalidate()
    iinaMonitorTimer = nil
  }

  private func startIINAMonitor() {
    iinaMonitorTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
      self?.checkIINAState()
    }
    checkIINAState()
  }

  private func isIINAApplicationRunning() -> Bool {
    return NSWorkspace.shared.runningApplications.contains { app in
      let identifier = (app.bundleIdentifier ?? "").lowercased()
      let name = (app.localizedName ?? "").lowercased()
      return identifier == "tv.kaleidoscope.iina" || name == "iina"
    }
  }

  private func checkIINAState() {
    let running = isIINAApplicationRunning()
    print("[IINAcord][IINA] IINA running = \(running)")
    DispatchQueue.main.async {
      self.menuController?.isIINAConnected = running
    }
    if running {
      self.discord?.showPlaceholderActivityIfNeeded()
    } else {
      self.discord?.clear()
    }
  }
}
