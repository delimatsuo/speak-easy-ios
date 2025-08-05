#!/usr/bin/env python3

import os
import uuid
import re

def generate_uuid():
    """Generate a 24-character hex UUID for Xcode"""
    return uuid.uuid4().hex[:24].upper()

def add_swift_files_to_project():
    project_path = "/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj/project.pbxproj"
    
    # Files to add
    files_to_add = [
        ("SpeakEasyColors.swift", "SpeakEasyColors.swift"),
        ("SpeakEasyIcon.swift", "SpeakEasyIcon.swift"),
        ("LaunchScreen.swift", "LaunchScreen.swift")
    ]
    
    # Read the current project file
    with open(project_path, 'r') as f:
        content = f.read()
    
    # Generate UUIDs and add file references
    file_entries = []
    build_entries = []
    
    for file_name, file_path in files_to_add:
        file_ref_uuid = generate_uuid()
        build_uuid = generate_uuid()
        
        # File reference entry
        file_ref = f'\t\t{file_ref_uuid} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_path}; sourceTree = "<group>"; }};'
        file_entries.append((file_ref_uuid, file_name, file_ref))
        
        # Build file entry
        build_file = f'\t\t{build_uuid} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {file_name} */; }};'
        build_entries.append((build_uuid, file_name, build_file))
    
    # Add file references
    file_ref_pattern = r'(577ED0340DAB4739BCDAEFC6 /\* Assets\.xcassets \*/ = \{[^}]+\};)'
    for _, _, file_ref in file_entries:
        content = re.sub(file_ref_pattern, f'\\1\n{file_ref}', file_ref_pattern)
        file_ref_pattern = f'({file_ref})'
    
    # Add to build files
    build_pattern = r'(/\* TranslationService\.swift in Sources \*/ = \{[^}]+\};)'
    for _, _, build_file in build_entries:
        content = re.sub(build_pattern, f'\\1\n{build_file}', content, count=1)
    
    # Add to sources build phase
    sources_pattern = r'(4351339FF4A6FAF3641529AC /\* TranslationService\.swift in Sources \*/,)'
    sources_additions = '\n'.join([f'\t\t\t\t{uuid} /* {name} in Sources */,' for uuid, name, _ in build_entries])
    content = re.sub(sources_pattern, f'\\1\n{sources_additions}', content)
    
    # Add to group
    group_pattern = r'(577ED0340DAB4739BCDAEFC6 /\* Assets\.xcassets \*/,)'
    group_additions = '\n'.join([f'\t\t\t\t{uuid} /* {name} */,' for uuid, name, _ in file_entries])
    content = re.sub(group_pattern, f'\\1\n{group_additions}', content)
    
    # Write back
    with open(project_path, 'w') as f:
        f.write(content)
    
    print("✅ Added missing Swift files to project!")
    for _, name, _ in file_entries:
        print(f"   - {name}")

if __name__ == "__main__":
    add_swift_files_to_project()