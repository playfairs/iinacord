import Combine
import Foundation

final class MenuBarController: ObservableObject {
  @Published var isIINAConnected: Bool = false
  @Published var isDiscordConnected: Bool = false
  @Published var socketStatus: String = "Starting"
  @Published var debugMessage: String = ""
  @Published var showPreferences: Bool = false
}
