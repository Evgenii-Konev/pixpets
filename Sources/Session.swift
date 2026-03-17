import Foundation

enum SessionStatus: String, Codable {
    case idle
    case working
    case waiting
}

struct Session: Equatable {
    let pid: Int32
    let agentType: AgentType
    var projectPath: String
    var projectName: String
    var status: SessionStatus
    var interactive: Bool
    var sessionId: String?
    var task: String?
    var parentPid: Int32?
    var updatedAt: Date

    static func == (lhs: Session, rhs: Session) -> Bool {
        if let lhsId = lhs.sessionId, let rhsId = rhs.sessionId {
            return lhsId == rhsId
        }
        return lhs.pid == rhs.pid
    }
}

/// JSON format written by hooks
struct SessionFile: Codable {
    let pid: Int
    let status: String
    let project: String?
    let agent: String?
    let session_id: String?
    let interactive: Bool?
    let parent_pid: Int?
    let task: String?
    let updated_at: Int?
}
