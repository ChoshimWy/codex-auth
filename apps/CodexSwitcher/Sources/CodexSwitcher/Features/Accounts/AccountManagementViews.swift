import SwiftUI
import AppKit

// MARK: - Alias Editor Sheet (FR-8)

/// 别名编辑 sheet:设置/重命名/清除,客户端预校验 + CLI 结构化错误内联展示。
struct AliasEditorSheet: View {
    let store: MenuBarStore

    @State private var aliasText: String = ""

    /// 设置 Tab 内嵌时隐藏 Close 按钮(弹窗呈现时保留)。
    var showsCloseButton: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(aliasTitle)
                .font(AppTypography.title)
                .foregroundStyle(StitchColor.onSurface)

            if let account = store.aliasSheetAccount {
                Text(account.email)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.onSurfaceVariant)
            }

            TextField(L10n.aliasPlaceholder, text: $aliasText)
                .textFieldStyle(.roundedBorder)

            if let message = store.aliasSheetMessage {
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.statusOrange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let error = store.errorMessage {
                // 非别名类错误(CLI 缺失/能力不足等)也在 sheet 内兜底展示。
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.statusOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if hasExistingAlias {
                    Button(L10n.aliasClearAction, role: .destructive) {
                        guard let account = store.aliasSheetAccount else { return }
                        Task { await store.clearAlias(for: account) }
                    }
                }
                Spacer()
                Button(L10n.cancelAction) { store.dismissAliasSheet() }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.aliasSaveAction) {
                    guard let account = store.aliasSheetAccount else { return }
                    Task { await store.setAlias(aliasText, for: account) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(aliasText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AppSpacing.lg)
        .frame(width: 360)
        .onAppear {
            aliasText = store.aliasSheetAccount?.alias ?? ""
        }
    }

    private var aliasTitle: String {
        hasExistingAlias ? L10n.aliasRenameTitle : L10n.aliasSetTitle
    }

    private var hasExistingAlias: Bool {
        !(store.aliasSheetAccount?.alias.isEmpty ?? true)
    }
}

// MARK: - Import Sheet (FR-9)

/// 导入面板:standard / cpa / purge(高级),文件或目录选择,结果逐行展示。
struct ImportAccountSheet: View {
    let store: MenuBarStore

    @State private var mode: ImportMode = .standard
    @State private var pickedPath: String?
    @State private var aliasText: String = ""
    @State private var showAdvanced = false
    @State private var showPurgeConfirm = false

    /// 设置 Tab 内嵌时隐藏 Close 按钮(弹窗呈现时保留)。
    var showsCloseButton: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(L10n.importTitle)
                .font(AppTypography.title)
                .foregroundStyle(StitchColor.onSurface)

            Picker(L10n.importModeLabel, selection: $mode) {
                Text(L10n.importModeStandard).tag(ImportMode.standard)
                Text(L10n.importModeCpa).tag(ImportMode.cpa)
            }
            .pickerStyle(.segmented)
            .disabled(store.managementBusy)

            HStack {
                Text(pickedPath ?? L10n.importNoPath)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.onSurfaceVariant)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(L10n.importChooseAction) {
                    if let path = Self.pickPath() {
                        pickedPath = path
                    }
                }
            }

            if mode == .standard {
                TextField(L10n.aliasOptionalLabel, text: $aliasText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(store.managementBusy)
            }

            DisclosureGroup(L10n.importAdvancedLabel, isExpanded: $showAdvanced) {
                Button(role: .destructive) {
                    showPurgeConfirm = true
                } label: {
                    Label(L10n.importPurgeAction, systemImage: "arrow.trianglehead.clockwise")
                }
                .disabled(store.managementBusy)
                Text(L10n.importPurgeWarning)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.statusOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.statusOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            importResults

            HStack {
                Spacer()
                if showsCloseButton {
                    Button(L10n.closeAction) { store.showImportSheet = false }
                        .keyboardShortcut(.cancelAction)
                }
                Button(L10n.importRunAction) { runImport() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(store.managementBusy || (mode == .standard && pickedPath == nil))
            }
        }
        .padding(AppSpacing.lg)
        .frame(width: 420)
        .confirmationDialog(
            L10n.importPurgeAction,
            isPresented: $showPurgeConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.importPurgeAction, role: .destructive) { runPurge() }
        } message: {
            Text(L10n.importPurgeWarning)
        }
    }

    @ViewBuilder
    private var importResults: some View {
        if let summary = store.lastImportSummary {
            Text(L10n.importSummary(summary.importedCount, summary.updatedCount, summary.skippedCount))
                .font(AppTypography.caption)
                .foregroundStyle(StitchColor.onSurfaceVariant)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(summary.results.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: AppSpacing.sm) {
                            Text(row.path).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(L10n.importStatus(row.status))
                                .foregroundStyle(row.status == "skipped" ? StitchColor.statusOrange : StitchColor.statusGreen)
                            if let reason = row.reason {
                                Text(reason)
                                    .foregroundStyle(StitchColor.onSurfaceVariant)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .font(AppTypography.caption)
                    }
                }
                .padding(.vertical, AppSpacing.xxs)
            }
            .frame(maxHeight: 140)
        }
    }

    private func runImport() {
        let alias = aliasText.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await store.runImport(
                path: mode == .standard ? pickedPath : (mode == .cpa ? pickedPath : nil),
                alias: mode == .standard && !alias.isEmpty ? alias : nil,
                mode: mode
            )
        }
    }

    private func runPurge() {
        Task { await store.runImport(path: pickedPath, alias: nil, mode: .purge) }
    }

    /// 原生选择器:允许文件与目录(auth.json 单文件或快照目录)。
    static func pickPath() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = L10n.importChooseAction
        guard panel.runModal() == .OK else { return nil }
        return panel.url?.path
    }
}

// MARK: - Export Sheet (FR-10)

/// 导出面板:格式选择、凭据披露确认、目标目录选择、结果与访达定位。
struct ExportAccountSheet: View {
    let store: MenuBarStore

    @State private var format: ExportFormat = .standard
    @State private var destination: String?
    @State private var showConsent = false

    /// 设置 Tab 内嵌时隐藏 Close 按钮(弹窗呈现时保留)。
    var showsCloseButton: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(L10n.exportTitle)
                .font(AppTypography.title)
                .foregroundStyle(StitchColor.onSurface)

            Picker(L10n.exportFormatLabel, selection: $format) {
                Text(L10n.exportFormatStandard).tag(ExportFormat.standard)
                Text(L10n.exportFormatCpa).tag(ExportFormat.cpa)
            }
            .pickerStyle(.segmented)
            .disabled(store.managementBusy)

            HStack {
                Text(destination ?? L10n.exportNoPath)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.onSurfaceVariant)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(L10n.exportChooseAction) {
                    if let path = Self.pickDirectory() {
                        destination = path
                    }
                }
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.statusOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let summary = store.lastExportSummary {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(L10n.exportSummary(summary.exportedCount, summary.skippedCount))
                        .font(AppTypography.caption)
                        .foregroundStyle(StitchColor.onSurfaceVariant)
                    HStack {
                        Button(L10n.exportRevealAction) {
                            NSWorkspace.shared.activateFileViewerSelecting(
                                [URL(fileURLWithPath: summary.destination)]
                            )
                        }
                        Spacer()
                    }
                }
            }

            HStack {
                Spacer()
                if showsCloseButton {
                    Button(L10n.closeAction) { store.showExportSheet = false }
                        .keyboardShortcut(.cancelAction)
                }
                Button(L10n.exportRunAction) {
                    // FR-10:执行前展示凭据披露确认。
                    showConsent = true
                }
                .keyboardShortcut(.defaultAction)
                .disabled(store.managementBusy)
            }
        }
        .padding(AppSpacing.lg)
        .frame(width: 420)
        .confirmationDialog(
            L10n.exportConsentTitle,
            isPresented: $showConsent,
            titleVisibility: .visible
        ) {
            Button(L10n.exportConsentConfirm) {
                Task { await store.runExport(destination: destination, format: format) }
            }
        } message: {
            Text(L10n.exportConsentMessage)
        }
    }

    static func pickDirectory() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = L10n.exportChooseAction
        guard panel.runModal() == .OK else { return nil }
        return panel.url?.path
    }
}
