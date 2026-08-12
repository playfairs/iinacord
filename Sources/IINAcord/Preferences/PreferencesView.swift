import SwiftUI

struct PreferencesView: View {
  @ObservedObject var model: PreferencesModel

  var body: some View {
    Form {
      Toggle("Launch at login", isOn: $model.launchAtLogin)
      Toggle("Enable Rich Presence", isOn: $model.enableRichPresence)
    }
    .padding()
    .frame(width: 360)
  }
}

struct PreferencesView_Previews: PreviewProvider {
  static var previews: some View {
    PreferencesView(model: PreferencesModel())
  }
}
