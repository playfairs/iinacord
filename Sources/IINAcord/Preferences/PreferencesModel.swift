import Foundation

final class PreferencesModel: ObservableObject {
  @Published var launchAtLogin: Bool {
    didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
  }
  @Published var enableRichPresence: Bool {
    didSet { UserDefaults.standard.set(enableRichPresence, forKey: "enableRichPresence") }
  }

  init() {
    launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
    enableRichPresence = UserDefaults.standard.object(forKey: "enableRichPresence") as? Bool ?? true
  }
}
