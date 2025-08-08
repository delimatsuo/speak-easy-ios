#!/usr/bin/env ruby
require 'xcodeproj'

# Path to your .xcodeproj file
project_path = '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
main_target = project.targets.first

# Path to the files you want to add
files_to_add = [
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/SpeakEasyColors.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/ResponsiveHelper.swift'
]

# Get the main group
main_group = project.main_group

# Add files to the project and target
files_to_add.each do |file_path|
  next unless File.exist?(file_path)
  
  # Check if file is already in the project
  file_name = File.basename(file_path)
  existing_file = main_group.files.find { |f| f.display_name == file_name }
  
  if existing_file
    puts "#{file_name} is already in the project"
  else
    # Create a file reference in the project
    file_ref = main_group.new_file(file_path)
    
    # Add file to build phase
    main_target.source_build_phase.add_file_reference(file_ref)
    
    puts "Added #{file_name} to the project and target"
  end
end

# Save the project
project.save
puts "Project saved successfully"