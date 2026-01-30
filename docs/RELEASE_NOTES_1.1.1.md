# Nolon 1.1.1

## What's New

### ✨ Features
- **MCP Editing**: Added support for editing MCP configurations and enabling/disabling them directly.
- **Enhanced Remote MCP**: Remote MCP cards now feature a "Show in Finder" option for easier access.
- **Git Caching**: Improved `GitRepository` and `RemoteSkillsGridView` with a caching mechanism and optimized data loading.

### 🛠 Refactoring
- **Parser Improvements**: Migrated skill content parsing to use `FrontmatterParser` for better reliability.
- **File System**: Migrated `FileManager` operations to `STFilePath` for a more structured file handling approach.
- **Architecture**: Refactored `GitRepository` and removed `LocalFolderService` to streamline the codebase.
