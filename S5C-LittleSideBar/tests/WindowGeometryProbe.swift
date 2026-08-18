import AppKit
import CoreGraphics
import Foundation

struct RectPayload: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }
}

struct DisplayPayload: Codable {
    let id: UInt32
    let frame: RectPayload
    let pixelWidth: Int
    let pixelHeight: Int
}

struct ScreenPayload: Codable {
    let name: String
    let frame: RectPayload
    let visibleFrame: RectPayload
    let scale: Double
}

struct WindowPayload: Codable {
    let owner: String
    let processIdentifier: Int32
    let title: String
    let bounds: RectPayload
}

struct ProbePayload: Codable {
    let displays: [DisplayPayload]
    let screens: [ScreenPayload]
    let finderWindows: [WindowPayload]
}

func activeDisplays() -> [DisplayPayload] {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success else { return [] }
    var identifiers = Array(repeating: CGDirectDisplayID(), count: Int(count))
    guard CGGetActiveDisplayList(count, &identifiers, &count) == .success else { return [] }
    return identifiers.prefix(Int(count)).map { identifier in
        DisplayPayload(
            id: identifier,
            frame: RectPayload(CGDisplayBounds(identifier)),
            pixelWidth: CGDisplayPixelsWide(identifier),
            pixelHeight: CGDisplayPixelsHigh(identifier)
        )
    }
}

func appKitScreens() -> [ScreenPayload] {
    _ = NSApplication.shared
    return NSScreen.screens.map { screen in
        ScreenPayload(
            name: screen.localizedName,
            frame: RectPayload(screen.frame),
            visibleFrame: RectPayload(screen.visibleFrame),
            scale: screen.backingScaleFactor
        )
    }
}

func finderWindows() -> [WindowPayload] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
        as? [[CFString: Any]] else { return [] }

    return rawWindows.compactMap { window in
        guard
            let owner = window[kCGWindowOwnerName] as? String,
            owner == "Finder" || owner == "访达",
            let layer = window[kCGWindowLayer] as? Int,
            layer == 0,
            let processIdentifier = window[kCGWindowOwnerPID] as? Int32,
            let boundsDictionary = window[kCGWindowBounds] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
        else { return nil }

        return WindowPayload(
            owner: owner,
            processIdentifier: processIdentifier,
            title: window[kCGWindowName] as? String ?? "",
            bounds: RectPayload(bounds)
        )
    }
    .sorted { lhs, rhs in
        lhs.bounds.width * lhs.bounds.height > rhs.bounds.width * rhs.bounds.height
    }
}

let payload = ProbePayload(
    displays: activeDisplays(),
    screens: appKitScreens(),
    finderWindows: finderWindows()
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
FileHandle.standardOutput.write(try encoder.encode(payload))
FileHandle.standardOutput.write(Data("\n".utf8))
