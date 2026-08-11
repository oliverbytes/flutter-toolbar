import Foundation

struct DaemonMessage {
    let id: Int?
    let event: String?
    let device: Device?
    let error: String?
    let emulators: [Device]?
    
    static func parse(data: Data) -> [DaemonMessage] {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { dict -> DaemonMessage? in
            let id = dict["id"] as? Int
            let event = dict["event"] as? String
            let errorDict = dict["error"] as? [String: Any]
            let error = errorDict?["message"] as? String
            
            let device: Device?
            if let params = dict["params"] as? [String: Any] {
                device = Device(from: params)
            } else {
                device = nil
            }
            
            let emulators: [Device]?
            if let result = dict["result"] as? [[String: Any]] {
                emulators = result.compactMap { Device(from: $0) }
            } else {
                emulators = nil
            }
            
            return DaemonMessage(
                id: id,
                event: event,
                device: device,
                error: error,
                emulators: emulators
            )
        }
    }
}