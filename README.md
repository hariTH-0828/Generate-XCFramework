# Generate Framework Script Documentation

## Overview
`zcocoframe.sh` is a Bash script designed to automate the process of building and archiving an Xcode project for multiple platforms (iOS, iOS Simulator, macOS, macOS (Designed for iPad) and macOS Catalyst). It also generates an XCFramework from the archived builds.

---

## Usage
```sh
./zcocoframe.sh -p <project_path>
```

### Parameters
| Parameter | Description |
|-----------|-------------|
| `-p` | Specifies the path to the Xcode project. This is required. |
| `-v` | Displays the current version of the script. |
| `-h` | Shows help information about how to use the script. |

If no project path is provided, the script defaults to the current directory (`./`).

---

## Features
- Lists available schemes in the Xcode project and allows the user to select one.
- Lists available destinations and allows the user to select multiple targets.
- Cleans the build folder before proceeding.
- Archives the project for selected destinations.
- Generates an XCFramework if required.

---

## Script Workflow
### 1. **Reading Project Path**
- Parses the `-p` flag to get the project path.
- Defaults to `./` if no path is provided.

### 2. **Fetching Xcode Project Information**
- Runs `xcodebuild -list` to retrieve:
  - Available Targets
  - Build Configurations
  - Schemes

### 3. **Selecting a Scheme**
- Displays all available schemes.
- Prompts the user to select one.

### 4. **Selecting Destinations**
- Displays available destinations:
  - `generic/platform=iOS`
  - `generic/platform=iOS Simulator`
  - `generic/platform=macOS,variant=Mac Catalyst`
  - `generic/platform=macOS,varient=Designed for iPad`
  - `generic/platform=macOS`
- Allows the user to select one or multiple destinations.

### 5. **Cleaning the Build Folder**
- Executes `xcodebuild clean` to remove previous build artifacts.

### 6. **Generating Archives**
- Archives the project for each selected destination.

### 7. **Creating an XCFramework (if applicable)**
- If multiple destinations are selected, the script generates an XCFramework using `xcodebuild -create-xcframework`.

---

## Example Execution
```sh
./zcocoframe.sh -p /Users/username/MyXcodeProject
```

### Sample Output
```
📂 Project path: /Users/username/MyXcodeProject
📌 Available Schemes:
1. MyApp
2. MyFramework
Select a scheme: 2
✅ Selected Scheme: MyFramework
📌 Available Destinations:
1. generic/platform=iOS
2. generic/platform=iOS Simulator
3. generic/platform=macOS,variant=Mac Catalyst
4. generic/platform=macOS,varient=Designed for iPad
5. generic/platform=macOS
Select destinations (comma-separated): 1,2
✅ Selected Destinations: iOS, iOS Simulator
🧹 Cleaning build folder...
✅ BUILD CLEAN SUCCEED
📦 Archiving iOS
📦 Archiving iOS Simulator
✅ Archive process completed successfully
🔨 Generating framework
✅ XCFramework created successfully
```

---

## Troubleshooting
### 1. **Failed to Run `xcodebuild -list`**
- Ensure you are in a directory containing an Xcode project or workspace.

### 2. **Build Fails During Archiving**
- Check if the selected scheme is correctly configured for the selected platform.
- Verify the project’s signing settings.

### 3. **XCFramework Not Generated**
- Ensure that archives for multiple platforms exist before attempting to create the XCFramework.

---

## Notes
- The script assumes that the project supports **generic/platform=iOS**, **iOS Simulator**, **macOS**, **macOS (Designed for iPad)** and **Mac Catalyst**.
- The script should be run in a terminal with the necessary permissions (`chmod +x zcocoframe.sh` before execution).

---

## Future Enhancements
- Add support for custom build configurations.
- Provide an option to skip clean before archiving.
- Improve error handling and user feedback.

---

## Author
[Hariharan R S]
[harisaravanan08112001@gmail.com]

