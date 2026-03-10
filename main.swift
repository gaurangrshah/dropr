import AppKit

let version = "1.0.0"

// MARK: - AirDrop CLI

class AirDropper: NSObject, NSSharingServiceDelegate {
    let files: [URL]
    private var timeoutTimer: DispatchSourceTimer?

    init(files: [URL]) {
        self.files = files
        super.init()
    }

    func send() {
        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            printError("AirDrop is not available on this Mac.")
            exit(1)
        }

        guard service.canPerform(withItems: files) else {
            printError("Cannot perform AirDrop with the given items.")
            exit(1)
        }

        service.delegate = self
        printInfo("Sending \(files.count) file(s) via AirDrop...")
        for file in files {
            printInfo("  \(file.lastPathComponent) (\(fileSize(file)))")
        }

        // Timeout after 5 minutes if picker is dismissed without callback
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 300)
        timer.setEventHandler {
            printError("AirDrop timed out (picker dismissed or no device selected).")
            exit(1)
        }
        timer.resume()
        timeoutTimer = timer

        service.perform(withItems: files as [Any])
    }

    // MARK: - NSSharingServiceDelegate

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        timeoutTimer?.cancel()
        printSuccess("AirDrop completed successfully.")
        NSApp.terminate(nil)
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: any Error) {
        timeoutTimer?.cancel()
        let msg = error.localizedDescription
        if msg.contains("cancel") || msg.contains("user") {
            printInfo("AirDrop cancelled.")
        } else {
            printError("AirDrop failed: \(msg)")
        }
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func fileSize(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let bytes = attrs[.size] as? Int64 else {
            return "unknown size"
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    let airdropper: AirDropper

    init(airdropper: AirDropper) {
        self.airdropper = airdropper
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        airdropper.send()
    }
}

// MARK: - Output helpers

let isTTY = isatty(STDOUT_FILENO) == 1

func printInfo(_ msg: String) {
    print(isTTY ? "\u{001B}[0;36m\(msg)\u{001B}[0m" : msg)
}

func printSuccess(_ msg: String) {
    print(isTTY ? "\u{001B}[0;32m\(msg)\u{001B}[0m" : msg)
}

func printError(_ msg: String) {
    let out = isTTY ? "\u{001B}[0;31m\(msg)\u{001B}[0m\n" : "\(msg)\n"
    fputs(out, stderr)
}

// MARK: - Main

let args = CommandLine.arguments.dropFirst()

if args.contains("-h") || args.contains("--help") {
    print("""
    Usage: airdrop-send <file1> [file2] ...

    Send files via AirDrop from the terminal.
    Opens the native macOS device picker.

    Options:
      -h, --help       Show this help
      -v, --version    Show version
    """)
    exit(0)
}

if args.contains("-v") || args.contains("--version") {
    print("airdrop-send \(version)")
    exit(0)
}

if args.isEmpty {
    printError("No files specified. Use --help for usage.")
    exit(1)
}

var files: [URL] = []
for arg in args {
    let path = (arg as NSString).expandingTildeInPath
    let url = URL(fileURLWithPath: path).standardizedFileURL
    guard FileManager.default.fileExists(atPath: url.path) else {
        printError("File not found: \(arg)")
        exit(1)
    }
    files.append(url)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let airdropper = AirDropper(files: files)
let delegate = AppDelegate(airdropper: airdropper)
app.delegate = delegate
app.run()
