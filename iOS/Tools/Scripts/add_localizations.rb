#!/usr/bin/env ruby
require 'xcodeproj'

# Path to your .xcodeproj file
project_path = '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
main_target = project.targets.first

# Add localization files
localizations = ['en', 'es', 'fr', 'de', 'it', 'pt-BR', 'zh-Hans', 'ja', 'ru', 'ko', 'ar', 'hi']

# Find or create Resources group
resources_group = project.main_group['Resources'] || project.main_group.new_group('Resources')

localizations.each do |lang|
  lproj_path = "/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/#{lang}.lproj"
  
  # Check if the .lproj folder exists
  if File.directory?(lproj_path)
    # Find or create the variant group for Localizable.strings
    variant_group = resources_group.children.find { |child| child.name == 'Localizable.strings' }
    
    if variant_group.nil?
      variant_group = resources_group.new_variant_group('Localizable.strings')
      main_target.resources_build_phase.add_file_reference(variant_group)
    end
    
    # Add the localization file to the variant group
    strings_file_path = "#{lproj_path}/Localizable.strings"
    if File.exist?(strings_file_path)
      file_ref = variant_group.new_reference(strings_file_path)
      file_ref.name = lang == 'pt-BR' ? 'Portuguese (Brazil)' : lang
      puts "Added #{lang} localization"
    end
  end
end

# Add localizations to project
project.root_object.known_regions = localizations

# Save the project
project.save

puts "Localizations added successfully"