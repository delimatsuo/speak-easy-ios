#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

# Path to your .xcodeproj file
project_path = '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main iOS target
ios_target = project.targets.find { |t| t.name == "UniversalTranslator" }

# Create watchOS app target if it doesn't exist
watch_app_target = project.targets.find { |t| t.name == "UniversalTranslator Watch App" }

if watch_app_target.nil?
  puts "Creating watchOS app target..."
  
  # Create the Watch App target
  watch_app_target = project.new_target(:application, 
                                        'UniversalTranslator Watch App', 
                                        :watchos,
                                        '8.0')
  
  # Configure build settings
  watch_app_target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.electususa.UniversalTranslator.watchkitapp'
    config.build_settings['INFOPLIST_FILE'] = 'watchOS/Info.plist'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
    config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '8.0'
    config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'Mervyn Talks'
    config.build_settings['INFOPLIST_KEY_UISupportedInterfaceOrientations'] = '["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown"]'
    config.build_settings['INFOPLIST_KEY_WKCompanionAppBundleIdentifier'] = 'com.electususa.UniversalTranslator'
    config.build_settings['INFOPLIST_KEY_WKRunsIndependently'] = 'NO'
    config.build_settings['SKIP_INSTALL'] = 'YES'
    config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
    config.build_settings['MARKETING_VERSION'] = '1.0'
  end
  
  puts "✅ Created watchOS app target"
else
  puts "watchOS app target already exists"
end

# Create groups for watchOS
watch_group = project.main_group.find_subpath('watchOS') || project.main_group.new_group('watchOS')
shared_group = project.main_group.find_subpath('Shared') || project.main_group.new_group('Shared')

# Files to add to Watch target
watch_files = [
  'watchOS/UniversalTranslatorWatchApp.swift',
  'watchOS/ContentView.swift',
  'watchOS/WatchAudioManager.swift',
  'watchOS/WatchConnectivityManager.swift',
]

# Shared files to add to both targets
shared_files = [
  'Shared/Models/TranslationRequest.swift',
  'Shared/Models/TranslationResponse.swift',
  'Shared/Models/AudioConstants.swift',
  'Shared/Models/TranslationError.swift',
]

# iOS files to update
ios_files = [
  'iOS/WatchSessionManager.swift'
]

# Function to add file to target
def add_file_to_target(project, group, file_path, target)
  full_path = "/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/#{file_path}"
  
  if File.exist?(full_path)
    # Check if file reference already exists
    file_ref = group.files.find { |f| f.path && f.path.end_with?(File.basename(file_path)) }
    
    if file_ref.nil?
      file_ref = group.new_file(full_path)
      puts "Added file reference: #{File.basename(file_path)}"
    else
      puts "File reference already exists: #{File.basename(file_path)}"
    end
    
    # Add to build phase if not already there
    unless target.source_build_phase.files.any? { |bf| bf.file_ref == file_ref }
      target.source_build_phase.add_file_reference(file_ref)
      puts "  ✅ Added to #{target.name} build phase"
    else
      puts "  ℹ️  Already in #{target.name} build phase"
    end
  else
    puts "  ⚠️  File not found: #{full_path}"
  end
end

# Add Watch files
puts "\nAdding Watch files..."
watch_files.each do |file_path|
  add_file_to_target(project, watch_group, file_path, watch_app_target)
end

# Add shared files to both targets
puts "\nAdding shared files..."
shared_files.each do |file_path|
  add_file_to_target(project, shared_group, file_path, watch_app_target)
  add_file_to_target(project, shared_group, file_path, ios_target)
end

# Add iOS Watch connectivity file
puts "\nAdding iOS Watch connectivity file..."
ios_group = project.main_group.find_subpath('iOS') || project.main_group
ios_files.each do |file_path|
  add_file_to_target(project, ios_group, file_path, ios_target)
end

# Add WatchConnectivity framework to both targets
puts "\nAdding WatchConnectivity framework..."

# For iOS target
ios_frameworks = ios_target.frameworks_build_phase
unless ios_frameworks.files.any? { |f| f.display_name == 'WatchConnectivity.framework' }
  ref = project.frameworks_group.new_reference('System/Library/Frameworks/WatchConnectivity.framework')
  ref.source_tree = 'SDKROOT'
  ios_frameworks.add_file_reference(ref)
  puts "  ✅ Added WatchConnectivity to iOS target"
end

# For Watch target
watch_frameworks = watch_app_target.frameworks_build_phase
unless watch_frameworks.files.any? { |f| f.display_name == 'WatchConnectivity.framework' }
  ref = project.frameworks_group.new_reference('System/Library/Frameworks/WatchConnectivity.framework')
  ref.source_tree = 'SDKROOT'
  watch_frameworks.add_file_reference(ref)
  puts "  ✅ Added WatchConnectivity to Watch target"
end

# Create dependency from iOS app to Watch app
unless ios_target.dependencies.any? { |d| d.target == watch_app_target }
  ios_target.add_dependency(watch_app_target)
  puts "\n✅ Added Watch app as dependency of iOS app"
end

# Add Watch app to embed frameworks build phase
embed_phase = ios_target.build_phases.find { |p| p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) && p.name == "Embed Watch Content" }

if embed_phase.nil?
  embed_phase = ios_target.new_copy_files_build_phase("Embed Watch Content")
  embed_phase.dst_subfolder_spec = '16'  # Products Directory
  embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
  puts "✅ Created Embed Watch Content build phase"
end

# Save the project
project.save
puts "\n✅ Project saved successfully!"
puts "\nNext steps:"
puts "1. Open the project in Xcode"
puts "2. Select the Watch App scheme and configure signing"
puts "3. Build and test the Watch app"
puts "4. Make sure the iOS app Info.plist includes NSMicrophoneUsageDescription"
puts "5. Test communication between iPhone and Watch apps"