#!/bin/bash

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

# Function to display usage
function show_usage() {
    echo "Usage: $0 -p <project_path> -d <destination>"
    echo "  -p: Project path (required)"
    echo "  -d: Destination (required)"
    exit 1
}

# Function to validate required params
function validate_params() {
    if [ -z "$PROJECT_PATH" ]; then
        echo -e "Error: Project path is required"
        show_usage
    fi
}

function set_default_path() {
    if [ -z "$PROJECT_PATH" ]; then
        PROJECT_PATH="./"
    fi
}

# Parse command line argument
while getopts "p:" opt; do
    case $opt in
        p)
            PROJECT_PATH=$OPTARG
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

# Change directory to the project path
cd "$PROJECT_PATH"

# Run xcodebuild -list and store the output
echo "📝 Fetching Xcode project information..."
echo ""
xcodebuild_output=$(xcodebuild -list 2>/dev/null)

# Check if xcodebuild was successful, $? -> exit status if the last command executed successfully
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

xcodebuild clean -scheme "$SELECTED_SCHEME"

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

    xcodebuild archive \
        -scheme "$SELECTED_SCHEME" \
        -destination "$destination" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH/${SELECTED_SCHEME}${archive_suffix}"
        SKIP_INSTALL=NO
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES
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