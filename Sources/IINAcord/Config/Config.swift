import Foundation

public struct Config {
  public static var clientID: String {
    if let env = ProcessInfo.processInfo.environment["IINACORD_CLIENT_ID"], !env.isEmpty {
      return env
    }
    return "1536964384885186570"
  }

  public static var appTitle: String {
    if let env = ProcessInfo.processInfo.environment["IINACORD_APP_TITLE"], !env.isEmpty {
      return env
    }
    return "IINA"
  }

  public static var largeImageKey: String {
    if let env = ProcessInfo.processInfo.environment["IINACORD_LARGE_IMAGE_KEY"], !env.isEmpty {
      return env
    }
    return "iina_large"
  }

  public static var largeImageText: String {
    if let env = ProcessInfo.processInfo.environment["IINACORD_LARGE_IMAGE_TEXT"], !env.isEmpty {
      return env
    }
    return "IINA"
  }

  public static var activityType: Int { 3 }

  public static func nonce() -> String { UUID().uuidString }
}
