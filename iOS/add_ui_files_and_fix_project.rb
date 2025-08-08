#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Resolve main app target (prefer one named 'UniversalTranslator')
main_target = project.targets.find { |t| t.name == 'UniversalTranslator' } || project.targets.first

# Files to ensure are added
files_to_add = [
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/DesignConstants.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/ModernLanguageSelector.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/ModernMicrophoneButton.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/ModernTextDisplayCard.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UsageStatsCard.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/SpeakEasyColors.swift',
  '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/HeroHeader.swift'
]

# Remove old/duplicate color file from target sources to avoid redeclaration conflicts
duplicate_color_path = '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator/SpeakEasyColors.swift'

def remove_file_from_target(project, target, absolute_path)
  file_ref = project.files.find { |f| f.path && File.expand_path(f.real_path) == absolute_path }
  return unless file_ref
  target.source_build_phase.files_references.each do |ref|
    if ref == file_ref
      build_file = target.source_build_phase.files.find { |bf| bf.file_ref == ref }
      target.source_build_phase.remove_build_file(build_file) if build_file
      puts "Removed from build: #{absolute_path}"
    end
  end
end

remove_file_from_target(project, main_target, duplicate_color_path)

# Ensure files exist in project and are part of build
main_group = project.main_group

def ensure_file_in_project(project, group, target, absolute_path)
  file_ref = project.files.find { |f| f.path && File.expand_path(f.real_path) == absolute_path }
  unless file_ref
    file_ref = group.new_file(absolute_path)
    puts "Added file reference: #{absolute_path}"
  end

  already_in_build = target.source_build_phase.files_references.include?(file_ref)
  unless already_in_build
    target.add_file_references([file_ref])
    puts "Added to build: #{absolute_path}"
  end
end

files_to_add.each do |path|
  if File.exist?(path)
    ensure_file_in_project(project, main_group, main_target, path)
  else
    puts "WARNING: Missing file: #{path}"
  end
end

project.save
puts 'Project updated successfully.'


