import Foundation
@testable import CodexSwitcher

/// 脚本化的 CLI runner:FIFO 消费预置结果,并记录每次调用参数。
/// 未预置结果时抛 `CLIError.executionFailed(127)` 模拟缺省失败。
final class FakeCLIProcessRunner: CLIProcessRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var script: [CLIRunResult] = []
    private var _invocations: [(executable: String, arguments: [String])] = []

    func enqueue(stdout: String, exitCode: Int32 = 0, stderr: String = "") {
        lock.lock()
        script.append(CLIRunResult(
            exitCode: exitCode,
            stdout: Data(stdout.utf8),
            stderr: Data(stderr.utf8)
        ))
        lock.unlock()
    }

    func run(executable: String, arguments: [String]) throws -> CLIRunResult {
        lock.lock()
        _invocations.append((executable, arguments))
        let next = script.isEmpty ? nil : script.removeFirst()
        lock.unlock()

        guard let next else {
            throw CLIError.executionFailed(127)
        }
        return next
    }

    /// 流式执行:把 FIFO 结果的 stdout 按行切分回调(login 多相位文档)。
    func runStreaming(
        executable: String,
        arguments: [String],
        isCancelled: @escaping @Sendable () -> Bool,
        onLine: @escaping @Sendable (Data) -> Void
    ) throws -> Int32 {
        let result = try run(executable: executable, arguments: arguments)
        var buffer = result.stdout
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            if !line.isEmpty { onLine(line) }
        }
        if !buffer.isEmpty { onLine(buffer) }
        return result.exitCode
    }

    var invocations: [(executable: String, arguments: [String])] {
        lock.lock()
        defer { lock.unlock() }
        return _invocations
    }

    func invocations(for command: String) -> [[String]] {
        invocations.filter { $0.arguments.first == command }.map(\.arguments)
    }
}

/// 线程安全的相位收集器(测试用:跨 @Sendable 回调边界收集)。
final class PhaseCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [String] = []

    func append(_ value: String) {
        lock.lock()
        _values.append(value)
        lock.unlock()
    }

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _values
    }
}

/// 线程安全的计数盒(测试用:跨 @Sendable 闭包计数)。
final class ThresholdCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0

    func increment() {
        lock.lock()
        _count += 1
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }
}
