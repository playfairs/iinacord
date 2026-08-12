import SwiftUI

@main
struct IINAcordApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
