import Foundation

public enum CodexAppServerMethod: String, Sendable, CaseIterable {
    case initialize
    case appList = "app/list"
    case commandExec = "command/exec"
    case configBatchWrite = "config/batchWrite"
    case configMcpServerReload = "config/mcpServer/reload"
    case configRead = "config/read"
    case configValueWrite = "config/value/write"
    case configRequirementsRead = "configRequirements/read"
    case experimentalFeatureList = "experimentalFeature/list"
    case externalAgentConfigDetect = "externalAgentConfig/detect"
    case externalAgentConfigImport = "externalAgentConfig/import"
    case feedbackUpload = "feedback/upload"
    case fuzzyFileSearch
    case mcpServerOAuthLogin = "mcpServer/oauth/login"
    case mcpServerStatusList = "mcpServerStatus/list"
    case modelList = "model/list"
    case reviewStart = "review/start"
    case skillsConfigWrite = "skills/config/write"
    case skillsList = "skills/list"
    case skillsRemoteExport = "skills/remote/export"
    case skillsRemoteList = "skills/remote/list"
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
    case threadUnsubscribe = "thread/unsubscribe"
    case threadUnarchive = "thread/unarchive"
    case turnInterrupt = "turn/interrupt"
    case turnSteer = "turn/steer"
    case turnStart = "turn/start"
    case windowsSandboxSetupStart = "windowsSandbox/setupStart"

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
    case configWarning
    case deprecationNotice
    case error
    case fuzzyFileSearchSessionCompleted = "fuzzyFileSearch/sessionCompleted"
    case fuzzyFileSearchSessionUpdated = "fuzzyFileSearch/sessionUpdated"
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
    case mcpServerOAuthLoginCompleted = "mcpServer/oauthLogin/completed"
    case modelRerouted = "model/rerouted"
    case serverRequestResolved = "serverRequest/resolved"
    case threadArchived = "thread/archived"
    case threadClosed = "thread/closed"
    case threadCompacted = "thread/compacted"
    case threadNameUpdated = "thread/name/updated"
    case threadRealtimeClosed = "thread/realtime/closed"
    case threadRealtimeError = "thread/realtime/error"
    case threadRealtimeItemAdded = "thread/realtime/itemAdded"
    case threadRealtimeOutputAudioDelta = "thread/realtime/outputAudio/delta"
    case threadRealtimeStarted = "thread/realtime/started"
    case threadStarted = "thread/started"
    case threadStatusChanged = "thread/status/changed"
    case threadTokenUsageUpdated = "thread/tokenUsage/updated"
    case threadUnarchived = "thread/unarchived"
    case turnCompleted = "turn/completed"
    case turnDiffUpdated = "turn/diff/updated"
    case turnPlanUpdated = "turn/plan/updated"
    case turnStarted = "turn/started"
    case windowsSandboxSetupCompleted = "windowsSandbox/setupCompleted"
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
