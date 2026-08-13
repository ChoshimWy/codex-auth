import XCTest
@testable import CodexSwitcher

final class InfrastructureUnitTests: XCTestCase {
    // MARK: - LineSplitter

    func testLineSplitterHandlesChunkedLinesAndRemainder() {
        let splitter = LineSplitter()

        // 跨 chunk 半行缓冲
        XCTAssertEqual(splitter.append(Data("first".utf8)), [])
        XCTAssertEqual(lines(of: splitter.append(Data("\nsecond\nthi".utf8))), ["first", "second"])
        XCTAssertEqual(lines(of: splitter.append(Data("rd\n".utf8))), ["third"])

        // 空行忽略
        XCTAssertEqual(splitter.append(Data("\n\n".utf8)), [])

        // drain 返回残留半行
        XCTAssertEqual(splitter.append(Data("tail".utf8)), [])
        XCTAssertEqual(splitter.drain().flatMap { String(data: $0, encoding: .utf8) }, "tail")
        XCTAssertNil(splitter.drain())
    }

    private func lines(of chunks: [Data]) -> [String] {
        chunks.compactMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - Semantic Version Comparison

    func testSemanticVersionComparison() {
        XCTAssertTrue(CLIInstaller.isVersion("0.10.0", newerThan: "0.9.0"))
        XCTAssertFalse(CLIInstaller.isVersion("0.9.0", newerThan: "0.10.0"))
        XCTAssertTrue(CLIInstaller.isVersion("0.3.1", newerThan: "0.3.0"))
        XCTAssertFalse(CLIInstaller.isVersion("0.3.0", newerThan: "0.3.0"))
        // 预发布视为更旧
        XCTAssertTrue(CLIInstaller.isVersion("0.3.0", newerThan: "0.3.0-alpha.10"))
        XCTAssertFalse(CLIInstaller.isVersion("0.3.0-alpha.10", newerThan: "0.3.0"))
    }

    // MARK: - Atomic Replace

    func testAtomicReplaceCopiesContentAndCleansTemp() throws {
        let fm = FileManager.default
        let directory = NSTemporaryDirectory() + "codex-installer-test-\(UUID().uuidString)"
        try fm.createDirectory(atPath: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: directory) }

        let source = directory + "/source"
        let dest = directory + "/codex-auth"
        try Data("binary-content".utf8).write(to: URL(fileURLWithPath: source))
        // 已有旧版本被覆盖
        try Data("old".utf8).write(to: URL(fileURLWithPath: dest))

        try CLIInstaller.atomicReplace(source: source, dest: dest)

        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: dest)), Data("binary-content".utf8))
        // 临时文件已清理
        XCTAssertFalse(fm.fileExists(atPath: directory + "/.codex-auth.install.tmp"))
    }
}
