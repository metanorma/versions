#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to update versions.yaml based on actual files on disk

require 'yaml'
require 'fileutils'

# Get the repository root directory (parent of scripts/)
REPO_ROOT = File.expand_path('..', __dir__)
DATA_DIR = File.join(REPO_ROOT, 'data', 'gemfile')
VERSIONS_FILE = File.join(DATA_DIR, 'versions.yaml')

def main
  data = YAML.load_file(VERSIONS_FILE)

  updated = 0
  data['versions'].each do |version_hash|
    version = version_hash['version']
    dir = File.join(DATA_DIR, "v#{version}")
    gemfile_path = File.join(dir, 'Gemfile')
    gemfile_lock_path = File.join(dir, 'Gemfile.lock.archived')

    exists = File.directory?(dir) && File.file?(gemfile_path) && File.file?(gemfile_lock_path)

    next unless exists

    version_hash['gemfile_exists'] = true
    # Store relative paths (relative to data/gemfile directory)
    version_hash['gemfile_path'] = "v#{version}/Gemfile"
    version_hash['gemfile_lock_path'] = "v#{version}/Gemfile.lock.archived"
    version_hash['parsed_at'] ||= Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
    updated += 1
    puts "Updated: #{version}"
  end

  # Update metadata
  data['metadata']['generated_at'] = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
  data['metadata']['count'] = data['versions'].size
  data['metadata']['latest_version'] = data['versions'].last['version']

  File.write(VERSIONS_FILE, data.to_yaml)

  puts "Done! Total: #{data['versions'].size}, Updated with files: #{updated}"
end

main
