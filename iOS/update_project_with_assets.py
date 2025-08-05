#!/usr/bin/env python3

import os
import uuid
import re

def generate_uuid():
    """Generate a 24-character hex UUID for Xcode"""
    return uuid.uuid4().hex[:24].upper()

def add_assets_to_pbxproj():
    project_path = "/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj/project.pbxproj"
    
    # Read the current project file
    with open(project_path, 'r') as f:
        content = f.read()
    
    # Generate UUIDs for the new references
    assets_ref_uuid = generate_uuid()
    assets_build_uuid = generate_uuid()
    
    # Add file reference for Assets.xcassets
    assets_file_ref = f'\t\t{assets_ref_uuid} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};'
    
    # Find the end of PBXFileReference section and add our reference
    file_ref_pattern = r'(/\* End PBXFileReference section \*/)'
    content = re.sub(file_ref_pattern, f'{assets_file_ref}\n\\1', content)
    
    # Add to the Resources build phase
    build_file_entry = f'\t\t\t\t{assets_build_uuid} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref_uuid} /* Assets.xcassets */; }};'
    
    # Find the Resources section and add our build file
    resources_pattern = r'(/\* GoogleService-Info.plist in Resources \*/; \};)'
    replacement = f'/* GoogleService-Info.plist in Resources */; }};\n{build_file_entry}'
    content = re.sub(resources_pattern, replacement, content)
    
    # Add to the Resources files list
    resources_files_pattern = r'(files = \(\s*0E01E00E8D0E7805BABBD9E8 /\* GoogleService-Info.plist in Resources \*/,)'
    replacement_files = f'files = (\n\t\t\t\t0E01E00E8D0E7805BABBD9E8 /* GoogleService-Info.plist in Resources */,\n\t\t\t\t{assets_build_uuid} /* Assets.xcassets in Resources */,'
    content = re.sub(resources_files_pattern, replacement_files, content)
    
    # Add to the main group (Recovered References group)
    group_pattern = r'("TEMP_5BEAF249-A45C-44C5-BA48-4AA7A94B0DB4" /\* GoogleService-Info.plist \*/,)'
    group_replacement = f'"TEMP_5BEAF249-A45C-44C5-BA48-4AA7A94B0DB4" /* GoogleService-Info.plist */,\n\t\t\t\t{assets_ref_uuid} /* Assets.xcassets */,'
    content = re.sub(group_pattern, group_replacement, content)
    
    # Write back the modified content
    with open(project_path, 'w') as f:
        f.write(content)
    
    print("✅ Successfully added Assets.xcassets to the Xcode project!")
    print(f"   - File reference UUID: {assets_ref_uuid}")
    print(f"   - Build file UUID: {assets_build_uuid}")
    print("\n📱 The app icons are now integrated into your project!")
    print("\nNext steps:")
    print("1. Open UniversalTranslator.xcodeproj in Xcode")
    print("2. Build and run the project")
    print("3. Your app should now display the Speak Easy icon!")

if __name__ == "__main__":
    add_assets_to_pbxproj()