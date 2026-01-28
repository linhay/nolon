import XCTest
@testable import nolon
import STJSON

@MainActor
final class MCPInstallationTests: XCTestCase {
    var fixture: TestFixture!
    var repository: SkillRepository!
    var installer: SkillInstaller!
    var viewModel: ProviderDetailGridViewModel!
    
    override func setUpWithError() throws {
        fixture = try TestFixture()
        repository = SkillRepository(fileManager: fixture.fileManager, nolonManager: fixture.nolonManager)
        installer = SkillInstaller(
            fileManager: fixture.fileManager,
            repository: repository,
            settings: fixture.providerSettings,
            nolonManager: fixture.nolonManager
        )
    }
    
    override func tearDownWithError() throws {
        fixture.cleanup()
    }
    
    func testRemoteMCP_Configuration() {
        let config = RemoteMCP.MCPConfiguration(
            command: "node",
            args: ["server.js"],
            env: ["API_KEY": "test-key"]
        )
        
        XCTAssertEqual(config.command, "node")
        XCTAssertEqual(config.args, ["server.js"])
        XCTAssertEqual(config.env, ["API_KEY": "test-key"])
    }
    
    func testRemoteMCP_Initialization() {
        let remoteMCP = RemoteMCP(
            slug: "test-mcp",
            displayName: "Test MCP",
            summary: "A test MCP server",
            latestVersion: "1.0.0",
            updatedAt: Date(),
            downloads: 100,
            stars: 50,
            configuration: RemoteMCP.MCPConfiguration(
                command: "node",
                args: ["server.js"]
            )
        )
        
        XCTAssertEqual(remoteMCP.slug, "test-mcp")
        XCTAssertEqual(remoteMCP.displayName, "Test MCP")
        XCTAssertEqual(remoteMCP.summary, "A test MCP server")
        XCTAssertNotNil(remoteMCP.configuration)
        XCTAssertEqual(remoteMCP.configuration?.command, "node")
        XCTAssertEqual(remoteMCP.stats?.downloads, 100)
        XCTAssertEqual(remoteMCP.stats?.stars, 50)
    }
    
    func testRemoteMCP_WithoutConfiguration() {
        let remoteMCP = RemoteMCP(
            slug: "test-mcp",
            displayName: "Test MCP",
            summary: "Test",
            latestVersion: nil,
            updatedAt: nil,
            downloads: nil,
            stars: nil,
            configuration: nil
        )
        
        XCTAssertEqual(remoteMCP.slug, "test-mcp")
        XCTAssertNil(remoteMCP.configuration)
        XCTAssertNil(remoteMCP.stats)
    }
    
    func testMCP_ModelCreation() {
        let mcpData: [String: Any] = [
            "command": "node",
            "args": ["server.js"],
            "env": ["API_KEY": "secret"]
        ]
        
        let mcp = MCP(name: "test-mcp", json: AnyCodable(mcpData))
        
        XCTAssertEqual(mcp.name, "test-mcp")
        
        if let jsonDict = mcp.json.value as? [String: Any] {
            XCTAssertEqual(jsonDict["command"] as? String, "node")
            XCTAssertEqual((jsonDict["args"] as? [String])?.first, "server.js")
        } else {
            XCTFail("Failed to parse MCP JSON")
        }
    }
    
    func testMcpWorkflow_Install() throws {
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        
        let mcp = MCP(
            name: "test-mcp",
            json: AnyCodable([
                "command": "node",
                "args": ["server.js"]
            ])
        )
        
        try installer.installMcpWorkflow(mcp: mcp, to: provider)
        
        let workflowPath = "\(provider.workflowPath)/\(mcp.name).md"
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: workflowPath))
    }
    
    func testMcpWorkflow_Uninstall() throws {
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        
        let mcp = MCP(
            name: "test-mcp",
            json: AnyCodable([
                "command": "node",
                "args": ["server.js"]
            ])
        )
        
        try installer.installMcpWorkflow(mcp: mcp, to: provider)
        
        let workflowPath = "\(provider.workflowPath)/\(mcp.name).md"
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: workflowPath))
        
        try installer.uninstallMcpWorkflow(mcp: mcp, from: provider)
        
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: workflowPath))
    }
    
    func testViewModel_MCP_FilteredResults() async throws {
        let provider = fixture.createProvider(name: "TestProvider", method: .symlink)
        
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)
        viewModel.mcps = [
            MCP(name: "mcp1", json: AnyCodable(["command": "cmd1"])),
            MCP(name: "mcp2", json: AnyCodable(["command": "cmd2"])),
            MCP(name: "another", json: AnyCodable(["command": "cmd3"]))
        ]
        
        viewModel.searchText = "mcp"
        
        let filtered = viewModel.filteredMcps
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains { $0.name == "mcp1" })
        XCTAssertTrue(filtered.contains { $0.name == "mcp2" })
        XCTAssertFalse(filtered.contains { $0.name == "another" })
    }
    
    func testViewModel_Workflow_FilteredResults() async throws {
        let provider = fixture.createProvider(name: "TestProvider", method: .symlink)
        
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)
        
        let workflow1 = WorkflowInfo(
            id: "workflow1",
            name: "Test Workflow",
            description: "Description",
            path: "/test/path1.md",
            source: .skill
        )
        
        let workflow2 = WorkflowInfo(
            id: "workflow2",
            name: "Another Workflow",
            description: "Description",
            path: "/test/path2.md",
            source: .skill
        )
        
        viewModel.workflows = [workflow1, workflow2]
        viewModel.searchText = "Test"
        
        let filtered = viewModel.filteredWorkflows
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "Test Workflow")
    }
}
