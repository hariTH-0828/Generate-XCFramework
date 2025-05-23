#!/bin/bash

# ------------------------------------------------------------------------------------------------------------- #
# ----------------------------------------------- ZCocoFrame.sh ----------------------------------------------- #
# ------------------------------------------------------------------------------------------------------------- #
VERSION=1.0.0

# ------------------------------------------------------------------------------------------------------------- #
# ----------------------------------------- Reading Xcode project path ---------------------------------------- #
# ------------------------------------------------------------------------------------------------------------- #

# Configuration variables
PROJECT_PATH=""
TARGETS=""
CONFIGURATIONS="Release"
SCHEMES=""
ARCHIVE_PATH="./build"
DESTINATION="iPhone
iPhone Simulator
macOS (Designed for iPad)
macOS (Mac Catalyst)
macOS"
SELECTED_DESTINATIONS=""
SELECTED_SCHEME=""

# Add a variable to track project type
PROJECT_TYPE=""
PROJECT_FILE=""

# Function to display version information
function show_version() {
    echo "Version: $VERSION"
    echo "Author: Hariharan R S"
    echo "Description: A script to automate the process of creating XCFrameworks from Xcode projects."
    exit 0
}

# Function to display usage
function show_usage() {
    echo "Usage: $0 [-p <project_path>] [-v] [-h]"
    echo "  -p: Project path (optional, defaults to current directory)"
    echo "  -v: Show version information"
    echo "  -h: Show this help message"
    exit 0
}

# Function to validate required params
function validate_params() {
    # All parameters are now optional with defaults
    return 0
}

function set_default_path() {
    if [ -z "$PROJECT_PATH" ]; then
        PROJECT_PATH="./"
    fi
}

# Parse command line argument
while getopts "p:vh" opt; do
    case $opt in
        p)
            PROJECT_PATH=$OPTARG
            ;;
        v)
            show_version
            ;;
        h)
            show_usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_usage
            ;;
    esac
done

set_default_path
validate_params

echo "📂 Project path: $PROJECT_PATH"
echo ""

# ------------------------------------------------------------------------------------------------------------- #
# ---------------------------------- Determine project type (workspace or project) ---------------------------- #
# ------------------------------------------------------------------------------------------------------------- #

# Change directory to the project path
cd "$PROJECT_PATH"

# Check if we're dealing with a workspace or project
WORKSPACE_COUNT=$(find . -maxdepth 1 -name "*.xcworkspace" | wc -l)
PROJECT_COUNT=$(find . -maxdepth 1 -name "*.xcodeproj" | wc -l)

if [ $WORKSPACE_COUNT -gt 0 ]; then
    PROJECT_TYPE="workspace"
    PROJECT_FILE=$(find . -maxdepth 1 -name "*.xcworkspace" | head -n 1 | sed 's|^\./||')
    echo "📂 Found workspace: $PROJECT_FILE"
elif [ $PROJECT_COUNT -gt 0 ]; then
    PROJECT_TYPE="project"
    PROJECT_FILE=$(find . -maxdepth 1 -name "*.xcodeproj" | head -n 1 | sed 's|^\./||')
    echo "📂 Found project: $PROJECT_FILE"
else
    echo "❌ Error: No .xcworkspace or .xcodeproj found in the specified directory"
    exit 1
fi

# ------------------------------------------------------------------------------------------------------------- #
# --------------------------------------------- Load scheme from the project ---------------------------------- #
# ------------------------------------------------------------------------------------------------------------- #

function extract_content() {
    local section_name=$1
    local capture=0
    
    while IFS= read -r line; do
        # Check for section start
        if [[ $line == *"$section_name:"* ]]; then
            capture=1
            continue
        fi
        
        # Check for next section (indicates end of current section)
        if [[ $capture -eq 1 && $line == *":"* && $line != *"$section_name:"* ]]; then
            capture=0
            continue
        fi
        
        # Capture content if we're in the right section
        if [[ $capture -eq 1 ]]; then
            # Trim whitespace
            trimmed_line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            
            # Skip empty lines
            if [[ -n "$trimmed_line" ]]; then
                echo "$trimmed_line"
            fi
        fi
    done
}

# Run xcodebuild -list and store the output
echo "📝 Fetching Xcode project information..."
echo ""

if [ "$PROJECT_TYPE" = "workspace" ]; then
    xcodebuild_output=$(xcodebuild -workspace "$PROJECT_FILE" -list 2>/dev/null)
else
    xcodebuild_output=$(xcodebuild -project "$PROJECT_FILE" -list 2>/dev/null)
fi

# Check if xcodebuild was successful
if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to run xcodebuild -list"
    echo "Make sure you're in a directory with an Xcode project or workspace"
    exit 1
fi

# Save to variables for potential further use
TARGETS=$(echo "$xcodebuild_output" | extract_content "Targets")
# CONFIGURATIONS=$(echo "$xcodebuild_output" | extract_content "Build Configurations")
SCHEMES=$(echo "$xcodebuild_output" | extract_content "Schemes")

# ------------------------------------------------------------------------------------------------------------- #
# ------------------------------------------ Select scheme from project --------------------------------------- #
# ------------------------------------------------------------------------------------------------------------- #

# Convert schemes to an array
IFS=$'\n' read -r -d '' -a scheme_array <<< "$SCHEMES"

# Display the schemes with numbers
echo "📌 Available Schemes:"
for i in "${!scheme_array[@]}"; do
    echo "$((i+1)). ${scheme_array[$i]}"
done

echo ""
# Ask user to select a scheme
read -p "Select a scheme: " scheme_index

# Validate input
if ! [[ "$scheme_index" =~ ^[0-9]+$ ]] || [ "$scheme_index" -lt 1 ] || [ "$scheme_index" -gt "${#scheme_array[@]}" ]; then
    echo ""
    echo "❌ Invalid selection. Please enter a number between 1 and ${#scheme_array[@]}"
    echo ""
    exit 1
fi

# Get the selected scheme
SELECTED_SCHEME="${scheme_array[$((scheme_index-1))]}"

echo ""
echo "✅ Selected Scheme: $SELECTED_SCHEME"
echo ""

# ------------------------------------------------------------------------------------------------------------- #
# -------------------------------------------- Select destination --------------------------------------------- #
# ------------------------------------------------------------------------------------------------------------- #

# Convert Schemes to an array
IFS=$'\n' read -r -d '' -a destination_array <<< "$DESTINATION"

# Display the destinations with numbers
echo "📌 Available Destinations:"
for i in "${!destination_array[@]}"; do
    echo "$((i+1)). ${destination_array[$i]}"
done

echo ""
# Read user selection
read -p "Select destinations: " destination_index

IFS=',' read -r -a selected_des_index <<< "$destination_index"
SELECTED_DESTINATIONS=()
for index in "${selected_des_index[@]}"; do 
    SELECTED_DESTINATIONS+=("${destination_array[index-1]}")
done

echo ""
printf "\n%s" "✅ Selected Destination: ${SELECTED_DESTINATIONS[@]}"
echo ""


# ------------------------------------------------------------------------------------------------------------- #
# --------------------------------------- Generate archive for destination ------------------------------------ #
# ------------------------------------------------------------------------------------------------------------- #

# Clean build folder
echo ""
echo "🧹 Cleaning build folder..."
echo ""

if [ "$PROJECT_TYPE" = "workspace" ]; then
    xcodebuild clean -workspace "$PROJECT_FILE" -scheme "$SELECTED_SCHEME"
else
    xcodebuild clean -project "$PROJECT_FILE" -scheme "$SELECTED_SCHEME"
fi

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Error: Failed to clean build folder"
    exit 1
fi

echo "✅ BUILD CLEAN SUCCEED"
echo ""

#Check if the build folder is exist remove the existing folder
if [ -d $ARCHIVE_PATH ]; then
    echo "🧹 Cleaning existing build folder..."
    echo ""
    rm -rf $ARCHIVE_PATH
fi

#Function to create archive
function create_archive() {
    local destination=$1
    local archive_suffix=$2

    echo "📦 Archiving for $destination..."
    echo ""

    if [ "$PROJECT_TYPE" = "workspace" ]; then
        xcodebuild archive \
            -workspace "$PROJECT_FILE" \
            -scheme "$SELECTED_SCHEME" \
            -destination "$destination" \
            -configuration Release \
            -archivePath "$ARCHIVE_PATH/${SELECTED_SCHEME}${archive_suffix}" \
            SKIP_INSTALL=NO \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES
    else
        xcodebuild archive \
            -scheme "$SELECTED_SCHEME" \
            -destination "$destination" \
            -configuration Release \
            -archivePath "$ARCHIVE_PATH/${SELECTED_SCHEME}${archive_suffix}" \
            SKIP_INSTALL=NO \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES
    fi
}

for destination in "${SELECTED_DESTINATIONS[@]}"; do
    case $destination in
        "iPhone")
            create_archive "generic/platform=iOS" ""
            ;;
        "iPhone Simulator")
            create_archive "generic/platform=iOS Simulator" "-simulator"
            ;;
        "macOS (Mac Catalyst)")
            create_archive "generic/platform=macOS,variant=Mac Catalyst" "-mac-catalyst"
            ;;
        "macOS (Designed for iPad)")
            create_archive "generic/platform=macOS,varient=Designed for iPad" "-mac-ipad"
            ;;
        "macOS")
            create_archive "generic/platform=macOS" "-mac"
            ;;
        *)
            echo "❌ Invalid destination"
            exit 1
            ;;
    esac
done

# Check if archive was successful
if [ ! -d $ARCHIVE_PATH ]; then
    echo "❌ Error: Failed to create archive"
    exit 1
fi

echo "✅ Archive process completed successfully"
echo ""

# ------------------------------------------------------------------------------------------------------------- #
# --------------------------------------- Generate build for framework ---------------------------------------- #
# ------------------------------------------------------------------------------------------------------------- #

#Function to create framework
function create_framework() {
    echo "🔨 Generating framework"
    echo ""

    args=()
    for destination in "${SELECTED_DESTINATIONS[@]}"; do
        case $destination in
            "iPhone")
                args+=("-framework" "$ARCHIVE_PATH/${SELECTED_SCHEME}.xcarchive/Products/Library/Frameworks/${SELECTED_SCHEME}.framework")
                ;;
            "iPhone Simulator")
                args+=("-framework" "$ARCHIVE_PATH/${SELECTED_SCHEME}-simulator.xcarchive/Products/Library/Frameworks/${SELECTED_SCHEME}.framework")
                ;;
            "macOS (Mac Catalyst)")
                args+=("-framework" "$ARCHIVE_PATH/${SELECTED_SCHEME}-mac-catalyst.xcarchive/Products/Library/Frameworks/${SELECTED_SCHEME}.framework")
                ;;
            "macOS (Designed for iPad)")
                args+=("-framework" "$ARCHIVE_PATH/${SELECTED_SCHEME}-mac-ipad.xcarchive/Products/Library/Frameworks/${SELECTED_SCHEME}.framework")
                ;;
            "macOS")
                args+=("-framework" "$ARCHIVE_PATH/${SELECTED_SCHEME}-mac.xcarchive/Products/Library/Frameworks/${SELECTED_SCHEME}.framework")
                ;;
            *)
                echo "❌ Invalid destination"
                exit 1
                ;;
        esac
    done

    (xcodebuild -create-xcframework "${args[@]}" -output "$ARCHIVE_PATH/${SELECTED_SCHEME}.xcframework" 2>&1) || {
        echo "❌ Error: Failed to generate framework"
        exit 1
    }

    echo "✅ XCFramework successfully created!"
}

create_framework