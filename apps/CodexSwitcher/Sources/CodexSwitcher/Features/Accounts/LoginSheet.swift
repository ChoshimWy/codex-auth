import SwiftUI
import AppKit

// MARK: - Login Sheet (FR-11)

/// device-auth 登录流:展示设备 URL 与一次性码,跟踪完成/失败,
/// 提供复制、打开浏览器、取消与 Terminal 回退。
struct LoginSheet: View {
    let store: MenuBarStore

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(L10n.loginTitle)
                .font(AppTypography.title)
                .foregroundStyle(StitchColor.onSurface)

            switch store.loginState {
            case .idle, .finishing:
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.loginWaiting)
                        .font(AppTypography.caption)
                        .foregroundStyle(StitchColor.onSurfaceVariant)
                }
                .padding(.vertical, AppSpacing.md)

            case .awaitingUser(let verificationURL, let userCode):
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(L10n.loginStepOpenLink)
                        .font(AppTypography.caption)
                        .foregroundStyle(StitchColor.onSurfaceVariant)
                    Text(verificationURL)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    Text(L10n.loginStepEnterCode)
                        .font(AppTypography.caption)
                        .foregroundStyle(StitchColor.onSurfaceVariant)
                    Text(userCode)
                        .font(.system(.title2, design: .monospaced))
                        .textSelection(.enabled)

                    HStack {
                        Button(L10n.loginCopyCode) { store.copyLoginCode() }
                        Button(L10n.loginOpenBrowser) { store.openLoginVerificationURL() }
                    }
                }

            case .completed:
                Label(L10n.loginCompleted, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(StitchColor.statusGreen)
                    .padding(.vertical, AppSpacing.md)

            case .failed(let message):
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(StitchColor.statusOrange)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.loginRetry) {
                        Task { await store.startLogin() }
                    }
                }
                .padding(.vertical, AppSpacing.md)
            }

            HStack {
                Button(L10n.loginTerminalFallback) {
                    store.dismissLoginSheet()
                    Task { await store.openTerminalLoginFallback() }
                }
                Spacer()
                Button(L10n.cancelAction) { store.dismissLoginSheet() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(AppSpacing.lg)
        .frame(width: 380)
        .onAppear {
            // 打开即开始登录流(幂等:仅 idle 时启动)。
            if store.loginState == .idle {
                Task { await store.startLogin() }
            }
        }
    }
}
