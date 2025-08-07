#!/bin/bash

# Script to rename all "VoiceBridge" references to "VoiceBridge" throughout the codebase
# Run from the root directory of the project

echo "🔄 Starting app name change from 'VoiceBridge' to 'VoiceBridge'..."

# Create backup
echo "📦 Creating backup..."
cp -r . ../UniversalTranslatorApp_backup_$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# Counter for changes
CHANGES=0

# Function to replace text in file
replace_in_file() {
    local file="$1"
    local search="$2"
    local replace="$3"
    
    if grep -q "$search" "$file" 2>/dev/null; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/$search/$replace/g" "$file"
        else
            # Linux
            sed -i "s/$search/$replace/g" "$file"
        fi
        echo "  ✅ Updated: $file"
        ((CHANGES++))
    fi
}

echo "📝 Updating documentation files..."
for file in $(find . -name "*.md" -type f | grep -v node_modules | grep -v .git | grep -v build); do
    replace_in_file "$file" "VoiceBridge" "VoiceBridge"
    replace_in_file "$file" "SPEAK EASY" "VOICEBRIDGE"
    replace_in_file "$file" "voicebridge" "voicebridge"
done

echo "📱 Updating Swift files..."
for file in $(find ./iOS -name "*.swift" -type f); do
    replace_in_file "$file" "VoiceBridge" "VoiceBridge"
    replace_in_file "$file" "SPEAK EASY" "VOICEBRIDGE"
done

echo "🔧 Updating configuration files..."
# Update shell scripts
for file in $(find . -name "*.sh" -type f | grep -v node_modules | grep -v .git); do
    replace_in_file "$file" "VoiceBridge" "VoiceBridge"
    replace_in_file "$file" "voicebridge" "voicebridge"
done

# Update Python scripts
for file in $(find . -name "*.py" -type f | grep -v node_modules | grep -v .git); do
    replace_in_file "$file" "VoiceBridge" "VoiceBridge"
    replace_in_file "$file" "voicebridge" "voicebridge"
done

# Update license file
replace_in_file "./LICENSE" "VoiceBridge" "VoiceBridge"

# Update specific files that might have different naming patterns
echo "🎯 Updating specific references..."

# Update GitHub repository references (but keep the actual repo URL intact for now)
for file in $(find . -name "*.md" -o -name "*.sh" | grep -v .git); do
    replace_in_file "$file" "VoiceBridge iOS App" "VoiceBridge iOS App"
    replace_in_file "$file" "VoiceBridge app" "VoiceBridge app"
done

# Update file names that contain "SPEAK_EASY"
echo "📁 Renaming files..."
for file in $(find . -name "*SPEAK_EASY*" -type f); do
    newfile=$(echo "$file" | sed 's/SPEAK_EASY/VOICEBRIDGE/g')
    if [ "$file" != "$newfile" ]; then
        mv "$file" "$newfile"
        echo "  ✅ Renamed: $(basename $file) → $(basename $newfile)"
        ((CHANGES++))
    fi
done

echo ""
echo "✨ App name change complete!"
echo "📊 Total changes made: $CHANGES"
echo ""
echo "⚠️  Note: The following items may still need manual updates:"
echo "  1. Xcode project name (if desired)"
echo "  2. GitHub repository name (optional)"
echo "  3. App Store Connect listing"
echo "  4. Any external documentation or marketing materials"
echo ""
echo "🔍 To verify all changes, run:"
echo "  grep -r 'VoiceBridge' . --exclude-dir=.git --exclude-dir=node_modules"