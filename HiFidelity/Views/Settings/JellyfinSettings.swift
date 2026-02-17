import Observation
import SwiftUI

struct JellyfinSettings: View {
    @Bindable var theme = AppTheme.shared
    @Bindable var jellyfin = JellyfinSessionManager.shared

    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            header
            connectionSection
            statusSection
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Jellyfin")
                .font(AppFonts.heading3)
                .foregroundColor(.primary)

            Text("Connect HiFidelity to your Jellyfin server")
                .font(AppFonts.captionLarge)
                .foregroundColor(.secondary)
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            inputRow(title: "Server URL") {
                TextField("https://jellyfin.example.com", text: $jellyfin.serverURL)
                    .textFieldStyle(.roundedBorder)
                    .disabled(jellyfin.isAuthenticating)
            }

            inputRow(title: "Username") {
                TextField("username", text: $jellyfin.username)
                    .textFieldStyle(.roundedBorder)
                    .disabled(jellyfin.isAuthenticating)
            }

            inputRow(title: "Password") {
                SecureField("password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .disabled(jellyfin.isAuthenticating || jellyfin.isAuthenticated)
            }

            HStack(spacing: DesignTokens.Spacing.md) {
                if jellyfin.isAuthenticated {
                    Button {
                        jellyfin.signOut()
                        password = ""
                    } label: {
                        Text("Disconnect")
                            .font(AppFonts.buttonSmall)
                    }
                    .buttonStyle(.bordered)
                    .disabled(jellyfin.isAuthenticating)

                    Button {
                        Task {
                            await jellyfin.testConnection()
                        }
                    } label: {
                        Text("Test Connection")
                            .font(AppFonts.buttonSmall)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.currentTheme.primaryColor)
                    .disabled(jellyfin.isAuthenticating)
                } else {
                    Button {
                        Task {
                            await jellyfin.signIn(password: password)
                            if jellyfin.isAuthenticated {
                                password = ""
                            }
                        }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            if jellyfin.isAuthenticating {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(jellyfin.isAuthenticating ? "Connecting..." : "Connect")
                                .font(AppFonts.buttonSmall)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.currentTheme.primaryColor)
                    .disabled(jellyfin.isAuthenticating)
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            statusRow(
                title: "Status",
                value: jellyfin.isAuthenticated ? "Connected" : "Disconnected",
                color: jellyfin.isAuthenticated ? theme.currentTheme.primaryColor : .secondary
            )

            statusRow(
                title: "User",
                value: jellyfin.connectedUserName ?? "-",
                color: .primary
            )

            if let message = jellyfin.lastErrorMessage, !message.isEmpty {
                statusRow(title: "Last Error", value: message, color: .red)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func inputRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(AppFonts.labelMedium)
                .foregroundColor(.secondary)
            content()
        }
    }

    private func statusRow(title: String, value: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(AppFonts.labelMedium)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(AppFonts.bodySmall)
                .foregroundColor(color)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    JellyfinSettings()
        .frame(width: DesignTokens.Size.Preview.librarySettingsWidth, height: 420)
}
