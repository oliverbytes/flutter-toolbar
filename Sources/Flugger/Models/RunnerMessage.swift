import Foundation

struct RunnerMessage {
    let id: Int?
    let event: String?
    let appId: String?
    let error: String?
    let progressMessage: String?
    let progressFinished: Bool?
    let debugWsUri: String?
    
    static func parse(data: Data) -> [RunnerMessage] {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { dict -> RunnerMessage? in
            let id = dict["id"] as? Int
            let event = dict["event"] as? String
            let errorDict = dict["error"] as? [String: Any]
            let error = errorDict?["message"] as? String
            
            var appId: String?
            var progressMessage: String?
            var progressFinished: Bool?
            var debugWsUri: String?
            
            if let params = dict["params"] as? [String: Any] {
                appId = params["appId"] as? String
                progressMessage = params["message"] as? String
                progressFinished = params["finished"] as? Bool
                debugWsUri = params["wsUri"] as? String
            }
            
            return RunnerMessage(
                id: id,
                event: event,
                appId: appId,
                error: error,
                progressMessage: progressMessage,
                progressFinished: progressFinished,
                debugWsUri: debugWsUri
            )
        }
    }
}