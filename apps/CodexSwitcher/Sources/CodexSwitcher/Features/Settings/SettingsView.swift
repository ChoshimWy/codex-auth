import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("lowCapacityThreshold") private var threshold: Double = 20.0
    @AppStorage("confirmBeforeSwitch") private var confirmSwitch: Bool = false
    @AppStorage("refreshInterval") private var refreshInterval: Int = 300
    @AppStorage("language") private var language: String = "system"
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    @Environment(\.dismiss) private var dismiss

    private let intervals: [(Int, String)] = [
        (60, "1 min"), (120, "2 min"), (300, "5 min"),
        (600, "10 min"), (900, "15 min"), (1800, "30 min"),
    ]

    var body: some View {
        TabView {
            GeneralSettingsView(
                threshold: $threshold,
                confirmSwitch: $confirmSwitch,
                refreshInterval: $refreshInterval,
                launchAtLogin: $launchAtLogin,
                intervals: intervals
            )
            .tabItem { Label(L10n.settingsGeneral, systemImage: "gearshape") }
            .frame(width: 440, height: 320)

            LanguageView(language: $language)
                .tabItem { Label(L10n.settingsLanguage, systemImage: "globe") }
                .frame(width: 440, height: 320)

            AboutView()
                .tabItem { Label(L10n.settingsAbout, systemImage: "info.circle") }
                .frame(width: 440, height: 320)
        }
        .padding(20)
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @Binding var threshold: Double
    @Binding var confirmSwitch: Bool
    @Binding var refreshInterval: Int
    @Binding var launchAtLogin: Bool
    let intervals: [(Int, String)]

    var body: some View {
        Form {
            Section {
                Slider(value: $threshold, in: 5...50, step: 5) {
                    Text(L10n.settingsLowThreshold(Int(threshold)))
                }
                Toggle(L10n.settingsConfirmSwitch, isOn: $confirmSwitch)
            }

            Section {
                Picker(L10n.settingsRefreshInterval, selection: $refreshInterval) {
                    ForEach(intervals, id: \.0) { val, label in
                        Text(label).tag(val)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                Toggle(L10n.settingsLaunchAtLogin, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = false
                        }
                    }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Language

private struct LanguageView: View {
    @Binding var language: String

    var body: some View {
        Form {
            Section {
                Picker(L10n.settingsLanguage, selection: $language) {
                    Text(L10n.settingsLangSystem).tag("system")
                    Text("English").tag("en")
                    Text("简体中文").tag("zh")
                }
                .pickerStyle(.radioGroup)
            }

            Section {
                Text(L10n.settingsLangNote)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.onSurfaceVariant)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "diamond")
                .font(.system(size: 48))
                .foregroundStyle(StitchColor.primaryContainer.gradient)

            Text(L10n.settingsAboutTitle)
                .font(.title2)
                .foregroundStyle(StitchColor.onSurface)

            Text(L10n.settingsAboutSubtitle)
                .font(AppTypography.caption)
                .foregroundStyle(StitchColor.onSurfaceVariant)

            Text(L10n.settingsVersion)
                .font(AppTypography.caption)
                .foregroundStyle(StitchColor.outline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
}
