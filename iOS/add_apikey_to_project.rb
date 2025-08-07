#!/usr/bin/env ruby

# Script to add APIKeyManager.swift to the Xcode project

require 'xcodeproj'

# Open the project
project_path = 'UniversalTranslator.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Find the main group (usually has the same name as the project)
main_group = project.main_group.children.find { |g| g.name == 'UniversalTranslator' || g.name == 'iOS' }
main_group ||= project.main_group

# Check if APIKeyManager.swift already exists in the project
existing_file = main_group.files.find { |f| f.path == 'APIKeyManager.swift' }

if existing_file
  puts "✅ APIKeyManager.swift already exists in the project"
else
  # Add the file reference
  file_ref = main_group.new_reference('APIKeyManager.swift')
  
  # Add to the compile sources build phase
  target.source_build_phase.add_file_reference(file_ref)
  
  puts "✅ Added APIKeyManager.swift to the project"
end

# Save the project
project.save

puts "✅ Project saved successfully"
puts ""
puts "📱 Next steps:"
puts "1. Clean Build Folder (Shift+Cmd+K)"
puts "2. Build and run the project"
puts "3. The API key should now be properly managed"