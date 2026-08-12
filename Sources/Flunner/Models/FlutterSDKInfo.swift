import Foundation

struct FlutterSDKInfo {
    let flutterPath: String
    let flutterVersion: String
    let channel: String
    let dartVersion: String
    let engineRevision: String?
    let frameworkRevision: String?
    let doctorCategories: [DoctorCategory]
}

struct DoctorCategory: Identifiable {
    let id = UUID()
    let name: String
    let status: DoctorStatus
    let details: [String]
}

enum DoctorStatus {
    case ok
    case warning
    case error
}
