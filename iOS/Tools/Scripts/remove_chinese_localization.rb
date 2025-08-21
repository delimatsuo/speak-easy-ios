#!/usr/bin/env ruby
require 'xcodeproj'

# Path to your .xcodeproj file
project_path = '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🗑️ Removing Chinese (zh-Hans) localization from Xcode project..."

# Remove zh-Hans from known regions
current_regions = project.root_object.known_regions
if current_regions.include?('zh-Hans')
  project.root_object.known_regions = current_regions - ['zh-Hans']
  puts "✅ Removed 'zh-Hans' from known regions"
else
  puts "ℹ️ 'zh-Hans' not found in known regions"
end

# Find and remove zh-Hans localization files and groups
def remove_chinese_references(group, removed_count = 0)
  return removed_count if group.nil?
  
  # Remove any file references with zh-Hans in the name or path
  group.children.each do |child|
    if child.respond_to?(:name) && child.name&.include?('zh-Hans')
      puts "🗑️ Removing file reference: #{child.name}"
      child.remove_from_project
      removed_count += 1
    elsif child.respond_to?(:path) && child.path&.include?('zh-Hans')
      puts "🗑️ Removing file reference with path: #{child.path}"
      child.remove_from_project
      removed_count += 1
    elsif child.respond_to?(:children) && child.children.any?
      # Recursively check subgroups
      removed_count = remove_chinese_references(child, removed_count)
    end
  end
  
  # Remove any groups named zh-Hans.lproj
  groups_to_remove = group.children.select do |child|
    child.respond_to?(:name) && child.name&.include?('zh-Hans')
  end
  
  groups_to_remove.each do |group_to_remove|
    puts "🗑️ Removing group: #{group_to_remove.name}"
    group_to_remove.remove_from_project
    removed_count += 1
  end
  
  removed_count
end

# Start removal from main group
removed_count = remove_chinese_references(project.main_group)

# Also check for any variant groups that might contain zh-Hans references
project.main_group.recursive_children.each do |child|
  if child.is_a?(Xcodeproj::Project::Object::PBXVariantGroup)
    child.children.each do |variant_child|
      if variant_child.respond_to?(:name) && variant_child.name&.include?('zh-Hans')
        puts "🗑️ Removing variant group child: #{variant_child.name}"
        variant_child.remove_from_project
        removed_count += 1
      end
    end
  end
end

# Save the project
project.save

puts "✅ Removed #{removed_count} Chinese localization references"
puts "✅ Chinese localization cleanup complete!"
puts "📱 You can now build the project without the missing file error"
