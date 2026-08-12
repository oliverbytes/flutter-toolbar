import AppKit
import Foundation

enum FlutterAppIconService {
    static func extractIcon(from projectPath: String) -> NSImage? {
        if let icon = iconFromAppleAssets(projectPath: projectPath, platform: "macos") {
            return icon
        }
        if let icon = iconFromAppleAssets(projectPath: projectPath, platform: "ios") {
            return icon
        }
        if let icon = iconFromAndroid(projectPath: projectPath) {
            return icon
        }
        return nil
    }

    private static func iconFromAppleAssets(projectPath: String, platform: String) -> NSImage? {
        let appiconsetPath = URL(fileURLWithPath: projectPath)
            .appendingPathComponent("\(platform)/Runner/Assets.xcassets/AppIcon.appiconset")
        let contentsURL = appiconsetPath.appendingPathComponent("Contents.json")

        guard FileManager.default.fileExists(atPath: contentsURL.path),
              let data = try? Data(contentsOf: contentsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let images = json["images"] as? [[String: Any]] else { return nil }

        let macImages = images.filter { $0["idiom"] as? String == "mac" || $0["idiom"] as? String == "iphone" || $0["idiom"] as? String == "ipad" }
        guard !macImages.isEmpty else { return nil }

        let bestEntry = macImages.max { a, b in
            let sizeA = parseSize(a["size"] as? String) ?? 0
            let scaleA = parseScale(a["scale"] as? String) ?? 0
            let sizeB = parseSize(b["size"] as? String) ?? 0
            let scaleB = parseScale(b["scale"] as? String) ?? 0
            return (sizeA * scaleA) < (sizeB * scaleB)
        }

        guard let entry = bestEntry,
              let filename = entry["filename"] as? String else { return nil }

        let imageURL = appiconsetPath.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: imageURL.path) else { return nil }
        return NSImage(contentsOf: imageURL)
    }

    private static func iconFromAndroid(projectPath: String) -> NSImage? {
        let densities = ["xxxhdpi", "xxhdpi", "xhdpi", "hdpi", "mdpi"]
        for density in densities {
            let iconPath = URL(fileURLWithPath: projectPath)
                .appendingPathComponent("android/app/src/main/res/mipmap-\(density)/ic_launcher.png")
            if FileManager.default.fileExists(atPath: iconPath.path),
               let image = NSImage(contentsOf: iconPath) {
                return image
            }
        }
        return nil
    }

    private static func parseSize(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        let parts = raw.components(separatedBy: "x")
        guard parts.count >= 2, let value = Double(parts[0]) else { return nil }
        return value
    }

    private static func parseScale(_ raw: String?) -> Double? {
        guard let raw, raw.hasSuffix("x") else { return nil }
        return Double(raw.dropLast())
    }
}
