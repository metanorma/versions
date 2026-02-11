# frozen_string_literal: true

require 'tty/prompt'
require_relative '../installer'

module Mnenv
  class InstallCommand < Thor
    namespace :install

    class_option :source, type: :string, enum: %w[gemfile tebako], default: 'gemfile',
                          desc: 'Installation source (gemfile or tebako)'
    class_option :interactive, type: :boolean, aliases: '-i', default: false,
                               desc: 'Interactive mode for version selection'

    desc '--list', 'List all available Metanorma versions'
    def list
      repo = GemfileRepository.new

      puts "Available Metanorma versions (source: #{options[:source]}):"
      repo.all.sort.each do |v|
        installed = Dir.exist?(File.expand_path("~/.mnenv/versions/#{v.version}"))
        installed_source = if installed
                             source_file = File.expand_path("~/.mnenv/versions/#{v.version}/source")
                             File.exist?(source_file) ? File.read(source_file).strip : 'unknown'
                           else
                             ''
                           end
        status = installed ? "[installed: #{installed_source}]" : '[        ]'
        puts "  #{status} #{v.display_name}"
      end
    end

    desc 'VERSION', 'Install a specific Metanorma version'
    method_option :source, type: :string, enum: %w[gemfile tebako], default: 'gemfile'
    method_option :interactive, type: :boolean, aliases: '-i', default: false
    def install(version = nil)
      if options[:interactive] || version.nil?
        version, source = select_installation_interactive
      else
        source = options[:source]
      end

      installer = InstallerFactory.create(version, source: source)

      if installer.installed?
        prompt = TTY::Prompt.new
        unless prompt.yes?("Version #{version} (source: #{source}) is already installed. Reinstall?")
          puts 'Installation cancelled.'
          return
        end
      end

      puts "Installing Metanorma #{version} (source: #{source})..."
      installer.install
      puts "Successfully installed Metanorma #{version} (source: #{source})!"
    rescue Installer::InstallationError => e
      warn "Error: #{e.message}"
      exit 1
    end

    default_task :install

    private

    def select_installation_interactive
      repo = GemfileRepository.new
      prompt = TTY::Prompt.new

      # First, select source
      source = prompt.select('Select installation source:', [
                               { name: 'Gemfile (faster, on-demand loading, requires dev tools, upgradable)',
                                 value: 'gemfile' },
                               { name: 'Tebako binary (slower, full-stack memory load, no dev tools, fixed)',
                                 value: 'tebako' }
                             ])

      # Then, select version
      choices = repo.all.sort.map do |v|
        installed = Dir.exist?(File.expand_path("~/.mnenv/versions/#{v.version}"))
        installed_source = if installed
                             source_file = File.expand_path("~/.mnenv/versions/#{v.version}/source")
                             File.exist?(source_file) ? "(#{File.read(source_file).strip})" : ''
                           else
                             ''
                           end
        { name: "#{v.display_name} #{installed ? "[installed: #{installed_source}]" : ''}", value: v.version }
      end

      version = prompt.select('Select a version to install:', choices)

      [version, source]
    end
  end
end
