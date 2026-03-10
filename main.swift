import AppKit

// MARK: - AirDrop CLI with file preview metadata

class AirDropper: NSObject, NSSharingServiceDelegate {
    let files: [URL]

    init(files: [URL]) {
        self.files = files
        super.init()
    }

    func send() {
        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            printError("AirDrop is not available on this Mac.")
            exit(1)
        }

        // Check capability with raw URLs
        guard service.canPerform(withItems: files) else {
            printError("Cannot perform AirDrop with the given items.")
            exit(1)
        }

        service.delegate = self
        printInfo("Sending \(files.count) file(s) via AirDrop...")
        for file in files {
            let size = fileSize(file)
            printInfo("  \(file.lastPathComponent) (\(size))")
        }

        // Pass raw file URLs — preview wrappers break the picker
        service.perform(withItems: files as [Any])
    }

    // MARK: - NSSharingServiceDelegate

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        printSuccess("AirDrop completed successfully.")
        NSApp.terminate(nil)
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: any Error) {
        printError("AirDrop failed: \(error.localizedDescription)")
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func fileSize(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let bytes = attrs[.size] as? Int64 else {
            return "unknown size"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
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
        // Bring the app to front so the AirDrop picker is visible
        NSApp.activate(ignoringOtherApps: true)
        airdropper.send()
    }
}

// MARK: - Terminal output helpers

func printInfo(_ msg: String) {
    print("\u{001B}[0;36m\(msg)\u{001B}[0m")
}

func printSuccess(_ msg: String) {
    print("\u{001B}[0;32m\(msg)\u{001B}[0m")
}

func printError(_ msg: String) {
    fputs("\u{001B}[0;31m\(msg)\u{001B}[0m\n", stderr)
}

// MARK: - Main

let args = CommandLine.arguments.dropFirst()

if args.isEmpty || args.contains("-h") || args.contains("--help") {
    print("""
    Usage: airdrop-send <file1> [file2] ...

    Send files via AirDrop with file name and icon preview.
    """)
    exit(0)
}

var files: [URL] = []
for arg in args {
    let url = URL(fileURLWithPath: (arg as NSString).expandingTildeInPath)
        .standardizedFileURL
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
