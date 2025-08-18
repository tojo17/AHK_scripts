# AutoHotkey Scripts Compilation Workflow

This GitHub Actions workflow automatically compiles AutoHotkey scripts to executable files, supporting both AutoHotkey v1.1 and v2.0 with 32-bit and 64-bit architecture options.

## Features

- ✅ **Multi-Version Support**: AutoHotkey v1.1 and v2.0
- ✅ **Multi-Architecture**: 32-bit and 64-bit compilation for each script
- ✅ **Section-Based Configuration**: Organize scripts by version in configuration file
- ✅ **Structured Output**: Clear directory organization by version and architecture
- ✅ **Multiple Artifacts**: Separate uploads for different combinations
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
   ├── v1/
   │   ├── x86/    # v1.1 32-bit executables
   │   └── x64/    # v1.1 64-bit executables
   └── v2/
       ├── x86/    # v2.0 32-bit executables
       └── x64/    # v2.0 64-bit executables
   ```

## Configuration

### scripts-to-compile.yml format:
```yaml
# AutoHotkey scripts compilation configuration
# This file defines which scripts to compile for each AutoHotkey version
# Each script will be compiled for both x86 (32-bit) and x64 (64-bit) architectures

ahk_v1:
  # AutoHotkey v1.1 scripts - compiled for both x86 and x64
  - "IME Switch/ime_switch.ahk"
  - "VirtualDesktopAccessor/example.ahk"
  - "keyboard_redefine/hhkb.ahk"
  - "keyboard_redefine/2.4GMouse.ahk"
  - "left click.ahk"
  - "man_lost_job.ahk"

ahk_v2:
  # AutoHotkey v2.0 scripts - compiled for both x86 and x64
  - "VirtualDesktopAccessor/example.ah2"
  - "VirtualDesktopAccessor/exe/virtual_desktop.ah2"
```

### Configuration Rules:
- Use `ahk_v1` section for AutoHotkey v1.1 scripts (usually `.ahk` files)
- Use `ahk_v2` section for AutoHotkey v2.0 scripts (usually `.ah2` files)
- Script paths are listed as YAML array items with quotes
- All paths are relative to repository root
- Comments start with `#` and are ignored
- Standard YAML syntax applies

## Usage

1. **Automatic**: Push changes to trigger compilation
2. **Manual**: Go to Actions tab → "Compile AutoHotkey Scripts" → "Run workflow"
3. **Release**: Create and push a git tag to generate a release with executables

## Output Files

Each script generates 4 executable files:
- `scriptname_x86.exe` (v1 32-bit)
- `scriptname_x64.exe` (v1 64-bit)
- `scriptname_x86.exe` (v2 32-bit)  
- `scriptname_x64.exe` (v2 64-bit)

## Artifacts

The workflow creates multiple artifacts for easy download:

1. **Version-Architecture Specific**:
   - `ahk-v1-x86-executables` - AutoHotkey v1.1 32-bit files
   - `ahk-v1-x64-executables` - AutoHotkey v1.1 64-bit files
   - `ahk-v2-x86-executables` - AutoHotkey v2.0 32-bit files
   - `ahk-v2-x64-executables` - AutoHotkey v2.0 64-bit files

2. **Combined**:
   - `all-compiled-executables` - All files in organized structure

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