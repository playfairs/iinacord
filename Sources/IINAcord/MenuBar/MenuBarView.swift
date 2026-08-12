import SwiftUI

struct MenuBarView: View {
  @ObservedObject var controller: MenuBarController

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("IINAcord").font(.headline)
      Divider()
      HStack {
        Text("IINA")
        Spacer()
        Text(controller.isIINAConnected ? "Connected" : "Disconnected")
      }
      HStack {
        Text("Discord")
        Spacer()
        Text(controller.isDiscordConnected ? "Connected" : "Disconnected")
      }
      HStack {
        Text("Socket")
        Spacer()
        Text(controller.socketStatus)
      }
      if !controller.debugMessage.isEmpty {
        Divider()
        Text(controller.debugMessage)
          .font(.footnote)
          .foregroundColor(.secondary)
          .lineLimit(3)
      }
      Divider()
      Button("Preferences…") {
        controller.showPreferences = true
      }
      Button("Quit IINAcord") {
        NSApplication.shared.terminate(nil)
      }
    }
    .padding(12)
    .frame(width: 320)
  }
}

struct MenuBarView_Previews: PreviewProvider {
  static var previews: some View {
    MenuBarView(controller: MenuBarController())
  }
}
