import Foundation

public enum CodexAppServerMethod: String, Sendable, CaseIterable {
    case initialize
    case addConversationListener
    case appList = "app/list"
    case archiveConversation
    case cancelLoginChatGpt
    case commandExec = "command/exec"
    case configBatchWrite = "config/batchWrite"
    case configMcpServerReload = "config/mcpServer/reload"
    case configRead = "config/read"
    case configValueWrite = "config/value/write"
    case configRequirementsRead = "configRequirements/read"
    case execOneOffCommand
    case experimentalFeatureList = "experimentalFeature/list"
    case feedbackUpload = "feedback/upload"
    case forkConversation
    case fuzzyFileSearch
    case getAuthStatus
    case getConversationSummary
    case getUserAgent
    case getUserSavedConfig
    case gitDiffToRemote
    case interruptConversation
    case listConversations
    case loginApiKey
    case loginChatGpt
    case logoutChatGpt
    case mcpServerOAuthLogin = "mcpServer/oauth/login"
    case mcpServerStatusList = "mcpServerStatus/list"
    case modelList = "model/list"
    case newConversation
    case removeConversationListener
    case resumeConversation
    case reviewStart = "review/start"
    case sendUserMessage
    case sendUserTurn
    case setDefaultModel
    case skillsConfigWrite = "skills/config/write"
    case skillsList = "skills/list"
    case skillsRemoteRead = "skills/remote/read"
    case skillsRemoteWrite = "skills/remote/write"
    case threadArchive = "thread/archive"
    case threadCompactStart = "thread/compact/start"
    case threadFork = "thread/fork"
    case threadList = "thread/list"
    case threadLoadedList = "thread/loaded/list"
    case threadNameSet = "thread/name/set"
    case threadRead = "thread/read"
    case threadResume = "thread/resume"
    case threadRollback = "thread/rollback"
    case threadStart = "thread/start"
    case threadUnarchive = "thread/unarchive"
    case turnInterrupt = "turn/interrupt"
    case turnSteer = "turn/steer"
    case turnStart = "turn/start"
    case userInfo

    case accountLoginStart = "account/login/start"
    case accountLoginCancel = "account/login/cancel"
    case accountLogout = "account/logout"
    case accountRateLimitsRead = "account/rateLimits/read"
    case accountRead = "account/read"
}

public enum CodexAppServerClientNotification: String, Sendable, CaseIterable {
    case initialized
}

public enum CodexAppServerServerNotification: String, Sendable, CaseIterable {
    case appListUpdated = "app/list/updated"
    case accountLoginCompleted = "account/login/completed"
    case accountRateLimitsUpdated = "account/rateLimits/updated"
    case accountUpdated = "account/updated"
    case authStatusChange
    case configWarning
    case deprecationNotice
    case error
    case itemAgentMessageDelta = "item/agentMessage/delta"
    case itemCommandExecutionOutputDelta = "item/commandExecution/outputDelta"
    case itemCommandExecutionTerminalInteraction = "item/commandExecution/terminalInteraction"
    case itemCompleted = "item/completed"
    case itemFileChangeOutputDelta = "item/fileChange/outputDelta"
    case itemMcpToolCallProgress = "item/mcpToolCall/progress"
    case itemPlanDelta = "item/plan/delta"
    case itemReasoningSummaryPartAdded = "item/reasoning/summaryPartAdded"
    case itemReasoningSummaryTextDelta = "item/reasoning/summaryTextDelta"
    case itemReasoningTextDelta = "item/reasoning/textDelta"
    case itemStarted = "item/started"
    case loginChatGptComplete
    case mcpServerOAuthLoginCompleted = "mcpServer/oauthLogin/completed"
    case rawResponseItemCompleted = "rawResponseItem/completed"
    case sessionConfigured
    case threadCompacted = "thread/compacted"
    case threadNameUpdated = "thread/name/updated"
    case threadStarted = "thread/started"
    case threadTokenUsageUpdated = "thread/tokenUsage/updated"
    case turnCompleted = "turn/completed"
    case turnDiffUpdated = "turn/diff/updated"
    case turnPlanUpdated = "turn/plan/updated"
    case turnStarted = "turn/started"
    case windowsWorldWritableWarning = "windows/worldWritableWarning"
}

public enum CodexAppServerServerRequest: String, Sendable, CaseIterable {
    case accountChatGPTAuthTokensRefresh = "account/chatgptAuthTokens/refresh"
    case applyPatchApproval
    case execCommandApproval
    case itemCommandExecutionRequestApproval = "item/commandExecution/requestApproval"
    case itemFileChangeRequestApproval = "item/fileChange/requestApproval"
    case itemToolCall = "item/tool/call"
    case itemToolRequestUserInput = "item/tool/requestUserInput"
}
