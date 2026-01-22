# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-21
**Project:** Nolon (macOS SwiftUI App)

## OVERVIEW
Nolon is a macOS skill manager for AI coding assistants (Codex, Claude, etc.). It centralizes skill management in `~/.nolon/skills` and installs them via symlinks or copying. Supports browsing and installing skills from **Clawdhub** remote repository. Built with SwiftUI and Clean Architecture.

## STRUCTURE
```
.
├── nolon/
│   ├── DesignSystem/     # **MANDATORY** color system & reusable UI components
│   ├── Skills/           # Core feature module (Clean Architecture)
│   │   ├── Models/       # Domain entities (Immutable structs)
│   │   │   ├── Skill.swift           # Local skill model
│   │   │   ├── Provider.swift        # Unified provider model
│   │   │   ├── RemoteSkill.swift     # Remote skill from Clawdhub
│   │   │   └── RemoteRepository.swift # Remote repository config
│   │   ├── Infrastructure/ # Side effects (Files, Parsing, Installation)
│   │   │   ├── SkillRepository.swift  # Local skill storage
│   │   │   ├── SkillInstaller.swift   # Install/Uninstall/Migrate
│   │   │   └── ClawdhubService.swift  # Clawdhub API client
│   │   └── Views/        # SwiftUI Views (SplitView pattern)
│   │       ├── MainSplitView.swift           # Main 3-column layout
│   │       ├── RemoteSkillsBrowserView.swift # Clawdhub browser (3-column)
│   │       └── ...
│   ├── Resources/        # Legacy localization (.lproj) - Deprecated
│   └── nolonApp.swift    # Entry point (@main)
├── Localizable.xcstrings # Modern localization source (En/Zh)
└── build.sh              # Custom CLI build/verification script
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **UI Colors** | `nolon/DesignSystem/AppColors.swift` | **MANDATORY**: Use `DesignSystem.Colors` ONLY. |
| **Domain Logic** | `nolon/Skills/Models/` | Pure Swift structs, `Sendable`, `Codable`. |
| **File Ops** | `nolon/Skills/Infrastructure/` | `SkillRepository`, `SkillInstaller`. |
| **Remote API** | `nolon/Skills/Infrastructure/ClawdhubService.swift` | Clawdhub API client. |
| **Parsing** | `nolon/Skills/Infrastructure/SkillParser.swift` | Custom regex parser for SKILL.md. |
| **Strings** | `Localizable.xcstrings` | Edit this for all text changes. |

## KEY CONCEPTS

### Installation Flow (Remote Skills)
1. Download zip from Clawdhub
2. Extract to `~/.nolon/skills/{slug}` (global storage)
3. Parse SKILL.md to create Skill model
4. Link/copy to provider directory based on `Provider.installMethod`

### Provider Model
- Unified `Provider` struct with configurable `installMethod` (`.symlink` or `.copy`)
- `ProviderTemplate` enum for quick provider setup
- `ProviderSettings` manages persistence via `@AppStorage`

## CONVENTIONS
- **Architecture**: Strict Clean Architecture (Models -> Infrastructure -> Views).
- **Concurrency**: Use `async/await`, `Sendable`, and `@MainActor` for all UI/State updates.
- **State**: `@StateObject` for view models, `@AppStorage` for simple settings.
- **Localization**: All UI strings MUST be localized.

## ANTI-PATTERNS (THIS PROJECT)
- **Forbidden Colors**: `Color.blue`, `Color.white`, `Color.label`. **USE** `DesignSystem.Colors.Brand`, `DesignSystem.Colors.Background`, etc.
- **Forbidden Logging**: `print()` in production code. Use `OSLog` or structured error handling.
- **Implicit Dependencies**: Infrastructure layer should not import Views.
- **Legacy Strings**: Do not add new files to `nolon/Resources/*.lproj`. Use `.xcstrings`.

## COMMANDS
```bash
# Verify Build
./build.sh

# Build Release
xcodebuild -project nolon.xcodeproj -scheme nolon -configuration Release
```

## NOTES
- **Remote Skills**: Supports browsing and installing from Clawdhub (https://clawdhub.com).
- **Migration**: The app includes a "Migration Assistant" to adopt orphaned skills found in provider directories.
- **Symlinks**: The app relies heavily on symlinks. Broken links are detected/repaired automatically.

## LOCALIZATION WORKFLOW
To translate new strings using an Agent:
1. **Extract**: Run `python3 nolon/scripts/extract_missing_translations.py` to generate `missing_translations.json`.
2. **Translate**: Provide the JSON content to an AI Agent to generate translations.
3. **Save**: Save the agent's output to `nolon/scripts/translated_items.json`.
4. **Import**: Run `python3 nolon/scripts/import_translations.py` to update `Localizable.xcstrings`.
