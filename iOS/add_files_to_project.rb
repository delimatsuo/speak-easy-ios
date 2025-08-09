#!/usr/bin/env ruby
require 'xcodeproj'

# Path to your .xcodeproj file
project_path = '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
main_target = project.targets.first

# Path to the files you want to add
files_to_add = [
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UsageTrackingService.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UsageStatisticsView.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/CreditsManager.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/PurchaseViewModel.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/CreditsBalanceView.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/PurchaseSheet.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/SignInView.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/AuthViewModel.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/Utilities/DeviceIdentity.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/Utilities/NetworkSecurityManager.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/ProfileView.swift'
]

# Get the main group
main_group = project.main_group

# Add files to the project and target
files_to_add.each do |file_path|
  # Create a file reference in the project
  file_ref = main_group.new_file(file_path)
  
  # Add file to build phase
  main_target.source_build_phase.add_file_reference(file_ref)
  
  puts "Added #{File.basename(file_path)} to the project and target"
end

# Save the project
project.save

puts "Project saved successfully"
