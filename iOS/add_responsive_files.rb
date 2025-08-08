#!/usr/bin/env ruby

# Script to add new responsive design files to the Xcode project

require 'xcodeproj'

# Open the Xcode project
project_path = 'UniversalTranslator.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |target| target.name == 'UniversalTranslator' }

# Find the main group (usually the project name group)
main_group = project.main_group.find_subpath('UniversalTranslator', true)

# Create a Modern UI group if it doesn't exist
modern_ui_group = main_group.find_subpath('Modern UI', true)

# Files to add
files_to_add = [
  'ResponsiveDesignHelper.swift',
  'ModernAnimations.swift', 
  'AccessibilitySupport.swift',
  'AdaptiveComponents.swift'
]

files_to_add.each do |filename|
  file_path = filename
  
  # Check if file already exists in project
  existing_file = project.files.find { |f| f.path.end_with?(filename) }
  
  if existing_file.nil?
    # Add file to project
    file_ref = modern_ui_group.new_reference(file_path)
    file_ref.last_known_file_type = 'sourcecode.swift'
    
    # Add to target
    target.add_file_references([file_ref])
    
    puts "Added #{filename} to project"
  else
    puts "#{filename} already exists in project"
  end
end

# Save the project
project.save

puts "Successfully updated Xcode project with responsive design files!"