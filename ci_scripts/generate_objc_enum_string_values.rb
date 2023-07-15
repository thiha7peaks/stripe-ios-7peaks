#!/usr/bin/env ruby

# This script finds Objective-C enums and autogenerates
# conformance to CustomStringConvertible which allows the
# debugger to print the case values themselves

require 'yaml'

OBJC_ENUM_REGEX = %r{
    (@available\([^)]*\))?\s* # Optional first capture: availability declaration
    @objc\s+ # find objc on preceding or same line
    (?:public\s+) # optionally find but don't caputure public keywork
    *enum\s+ # enum declaration
    (\w+) # Second capture: enum name
    [^{]*{ # advance to open bracket
    ([^}]*)} # Third capture: everything until closing bracket
    }x
    
    CASE_NAME_REGEX = %r{
        case\s+(\`*\w+\`*)
    }x
    
    XCODE_TAB = "    "
                
SCRIPT_DIR = __dir__
if SCRIPT_DIR.nil? || SCRIPT_DIR.empty?
    abort "Unable to find SCRIPT_DIR"
end
puts SCRIPT_DIR
ROOT_DIR = File.expand_path("..", SCRIPT_DIR)
if ROOT_DIR.nil? || ROOT_DIR.empty?
    abort "Unable to find ROOT_DIR"
end
puts ROOT_DIR
                
# Load modules from yaml and filter out any which don't have custom_string_convertible_dir configured
modules = YAML.load_file("#{ROOT_DIR}/modules.yaml")['modules'].select { |m| !m['custom_string_convertible_dir'].nil? }
                
modules.each do |m|
    module_dir = m['framework_name'].to_s # assumes directory names match framework names
    generated_file_dir = m['custom_string_convertible_dir'].to_s
    File.open("#{generated_file_dir}/Enums+CustomStringConvertible.swift", 'w') do |generated_file|
        # write header
        generated_file.puts(%q(//
//  Enums+CustomStringConvertible.swift
//  Stripe
//
//  Autogenerated by generate_objc_enum_string_values.rb
//  Copyright © 2021 Stripe, Inc. All rights reserved.
//
                               ))
        target_enums = []
        # search swift files
        Dir.glob("#{module_dir}/**/*.swift") do |file_name|
            File.open(file_name, 'r') do |file|
                enums = file.read().scan(OBJC_ENUM_REGEX)
                unless enums.empty?
                    target_enums.concat(enums)
                end
                
            end
        end
        # sort enums for target
        target_enums = target_enums.sort do |a,b|
            a[1] <=> b[1]
        end
        # enumerate objc_enum_regex matches format: [availability?, name, cases_group]
        target_enums.each do |found_enum|
            generated_file.puts("/// :nodoc:")
            unless found_enum[0].to_s.strip.empty?
                generated_file.puts(found_enum[0])
            end
                
            enum_name = found_enum[1]
            cases = found_enum[2].scan(CASE_NAME_REGEX)
                
            generated_file.puts("extension #{enum_name}: CustomStringConvertible {")
            generated_file.puts("#{XCODE_TAB}public var description: String {\n#{XCODE_TAB}#{XCODE_TAB}switch self {")
                
            cases = cases.sort do |a,b|
                a[0] <=> b[0]
            end
            cases.each do |case_name|
                case_name = case_name[0] # case_name is in an array
                generated_file.puts("#{XCODE_TAB}#{XCODE_TAB}case .#{case_name}:")
                generated_file.puts("#{XCODE_TAB}#{XCODE_TAB}#{XCODE_TAB}return \"#{case_name}\"")
            end
            generated_file.puts("#{XCODE_TAB}#{XCODE_TAB}}\n#{XCODE_TAB}}\n}\n\n")
        end
    end
end
