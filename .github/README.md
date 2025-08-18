# AutoHotkey Scripts Compilation Workflow

This GitHub Actions workflow automatically compiles AutoHotkey scripts to executable files, supporting both AutoHotkey v1.1 and v2.0 with 32-bit and 64-bit architecture options.

## Features

- ✅ **Multi-Version Support**: AutoHotkey v1.1 and v2.0
- ✅ **Multi-Architecture**: 32-bit and 64-bit compilation for each script
- ✅ **Dependency Management**: Automatic copying of DLL files and other dependencies alongside executables
- ✅ **Flexible Configuration**: Support for both simple script paths and complex objects with dependencies
- ✅ **Section-Based Configuration**: Organize scripts by version in configuration file
- ✅ **Structured Output**: Clear directory organization by architecture
- ✅ **Version-Architecture Naming**: Executables are named with version and architecture suffixes
- ✅ **Auto-Release**: Tag-triggered releases with detailed descriptions

## How it works

1. **Trigger**: The workflow runs on:
   - Push to `master` or `main` branch
   - Pull requests to `master` or `main` branch
   - Manual trigger (workflow_dispatch)

2. **Installation**: The workflow installs both:
   - AutoHotkey v1.1 (latest stable)
   - AutoHotkey v2.0 (latest stable)

3. **Compilation**: For each script:
   - Reads version-specific configuration from `scripts-to-compile.yml`
   - Compiles each script in both 32-bit and 64-bit versions
   - Uses appropriate compiler and runtime for each AutoHotkey version
   - Maintains original directory structure in organized output

4. **Output Structure**:
   ```
   compiled/
   ├── x86/    # 32-bit executables (both v1 and v2) with dependencies
   └── x64/    # 64-bit executables (both v1 and v2) with dependencies
   ```

## Configuration

### scripts-to-compile.yml format:
```yaml
# AutoHotkey scripts compilation configuration
# This file defines which scripts to compile for each AutoHotkey version
# Each script will be compiled for both x86 (32-bit) and x64 (64-bit) architectures
#
# Configuration formats supported:
# 1. Simple string format (no dependencies):
#    - "path/to/script.ahk"
# 2. Object format with single dependency:
#    - path: "path/to/script.ahk"
#      deps: "path/to/dependency.dll"
# 3. Object format with multiple dependencies:
#    - path: "path/to/script.ahk"
#      deps:
#        - "path/to/dependency1.dll"
#        - "path/to/dependency2.dll"

ahk_v1:
  # AutoHotkey v1.1 scripts - compiled for both x86 and x64
  - "keyboard_redefine/hhkb.ahk"
  - "keyboard_redefine/2.4GMouse.ahk"
  - "left click.ahk"

ahk_v2:
  # AutoHotkey v2.0 scripts - compiled for both x86 and x64
  - path: "VirtualDesktopAccessor/exe/virtual_desktop.ah2"
    deps: "VirtualDesktopAccessor/exe/VirtualDesktopAccessor.dll"
```

### Configuration Rules:
- Use `ahk_v1` section for AutoHotkey v1.1 scripts (usually `.ahk` files)
- Use `ahk_v2` section for AutoHotkey v2.0 scripts (usually `.ah2` files)
- Script paths can be in simple string format or object format with dependencies
- For scripts with dependencies, use object format with `path` and `deps` fields
- Dependencies (DLL files, etc.) are automatically copied to the output directory alongside executables
- All paths are relative to repository root
- Comments start with `#` and are ignored
- Standard YAML syntax applies

## Usage

1. **Automatic**: Push changes to trigger compilation
2. **Manual**: Go to Actions tab → "Compile AutoHotkey Scripts" → "Run workflow"
3. **Release**: Create and push a git tag to generate a release with executables

## Output Files

Each script generates executable files with version and architecture suffixes:
- `scriptname-v1-x86.exe` (v1 32-bit)
- `scriptname-v1-x64.exe` (v1 64-bit)
- `scriptname-v2-x86.exe` (v2 32-bit)  
- `scriptname-v2-x64.exe` (v2 64-bit)

Scripts with dependencies will have their dependency files (DLL, etc.) copied to the same directory as the executable.

## Artifacts

The workflow creates a single artifact containing all compiled executables:
- `ahkexe-{run-number}-{timestamp}` - All compiled executables organized by architecture with their dependencies

The artifact contains the complete compiled/ directory structure with x86/ and x64/ subdirectories.

## Release Notes

When creating releases with git tags, the workflow automatically generates releases with:
- All compiled executables attached
- Detailed usage instructions
- Clear directory structure explanation

## Troubleshooting

- **Script not found**: Verify paths in `scripts-to-compile.yml` are correct and relative to repository root
- **YAML syntax errors**: Ensure proper YAML formatting with correct indentation and quotes
- **Compilation failures**: Check AutoHotkey syntax compatibility between v1 and v2
- **Missing executables**: Ensure scripts are in correct version sections (`ahk_v1` or `ahk_v2`)