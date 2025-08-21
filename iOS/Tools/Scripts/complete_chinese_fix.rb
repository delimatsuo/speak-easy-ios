#!/usr/bin/env ruby
require 'xcodeproj'

# Path to your .xcodeproj file
project_path = '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Complete Chinese localization fix..."

# Step 1: Remove ALL zh-Hans references completely
puts "🗑️ Removing all zh-Hans references..."
objects_to_remove = []

project.objects.each do |uuid, object|
  should_remove = false
  
  if object.respond_to?(:path) && object.path&.include?('zh-Hans')
    puts "   - Found path reference: #{object.path}"
    should_remove = true
  elsif object.respond_to?(:name) && object.name&.include?('zh-Hans')
    puts "   - Found name reference: #{object.name}"
    should_remove = true
  elsif object.is_a?(String) && object.include?('zh-Hans')
    puts "   - Found string reference: #{object}"
    should_remove = true
  end
  
  if should_remove
    objects_to_remove << uuid
  end
end

# Remove the objects
objects_to_remove.each do |uuid|
  puts "   - Removing object: #{uuid}"
  project.objects.delete(uuid)
end

# Step 2: Remove zh-Hans from known regions if present
current_regions = project.root_object.known_regions || []
if current_regions.include?('zh-Hans')
  project.root_object.known_regions = current_regions.reject { |r| r == 'zh-Hans' }
  puts "✅ Removed 'zh-Hans' from known regions"
end

# Step 3: Ensure zh-CN is properly set up
puts "📱 Setting up zh-CN localization..."

# Find the main group and resources
main_group = project.main_group
resources_group = main_group['Resources'] || main_group.new_group('Resources')
localization_group = resources_group['Localization'] || resources_group.new_group('Localization')

# Find the Localizable.strings variant group
variant_group = nil
project.objects.each do |uuid, obj|
  if obj.is_a?(Xcodeproj::Project::Object::PBXVariantGroup) && obj.name == 'Localizable.strings'
    variant_group = obj
    break
  end
end

# If no variant group exists, create it
if variant_group.nil?
  puts "   - Creating new Localizable.strings variant group"
  variant_group = localization_group.new_variant_group('Localizable.strings')
  
  # Add to build phase
  target = project.targets.first
  target.resources_build_phase.add_file_reference(variant_group)
end

# Check if zh-CN reference already exists in variant group
zh_cn_exists = variant_group.children.any? { |child| child.name == 'zh-CN' }

unless zh_cn_exists
  puts "   - Adding zh-CN localization file reference"
  
  # Create the file reference for zh-CN
  chinese_file_path = "Resources/Localization/zh-CN.lproj/Localizable.strings"
  file_ref = variant_group.new_reference(chinese_file_path)
  file_ref.name = 'zh-CN'
  file_ref.last_known_file_type = 'text.plist.strings'
end

# Step 4: Ensure zh-CN is in known regions
current_regions = project.root_object.known_regions || []
unless current_regions.include?('zh-CN')
  project.root_object.known_regions = current_regions + ['zh-CN']
  puts "✅ Added 'zh-CN' to known regions"
end

# Step 5: Clean up any orphaned references
puts "🧹 Cleaning up orphaned references..."
project.objects.each do |uuid, object|
  if object.respond_to?(:file_ref) && object.file_ref.nil?
    puts "   - Removing orphaned reference: #{uuid}"
    project.objects.delete(uuid)
  end
end

# Save the project
project.save

puts "✅ Complete Chinese localization fix completed!"
puts "📱 Project should now build without zh-Hans errors"
puts "🇨🇳 Chinese (zh-CN) localization properly configured"
