# frozen_string_literal: true

require 'set'

module Mnenv
  class ShimManager
    SHIMS_DIR = File.expand_path('~/.mnenv/shims').freeze
    VERSIONS_DIR = File.expand_path('~/.mnenv/versions').freeze
    RESOLVER_SCRIPT = File.expand_path('../resolver', __dir__).freeze

    attr_reader :shims_dir

    def initialize(shims_dir: nil)
      @shims_dir = shims_dir || SHIMS_DIR
    end

    def regenerate_all
      FileUtils.mkdir_p(@shims_dir)

      executables = discover_executables

      executables.each do |exe|
        create_shim(exe)
      end

      remove_obsolete_shims(executables)
    end

    def create_shim(executable_name)
      shim_path = File.join(@shims_dir, executable_name)

      File.write(shim_path, shim_content(executable_name))
      File.chmod(0o755, shim_path)
    end

    private

    def discover_executables
      executables = Set.new

      # Discover from gemfile installations (binstubs in bin/)
      bin_pattern = File.join(VERSIONS_DIR, '*', 'bin', '*')
      Dir.glob(bin_pattern).each do |bin_path|
        executables << File.basename(bin_path) if File.executable?(bin_path)
      end

      # Discover from tebako installations (single metanorma binary)
      tebako_pattern = File.join(VERSIONS_DIR, '*', 'metanorma')
      Dir.glob(tebako_pattern).each do |bin_path|
        # Only if it's a tebako installation (has "source" file containing "tebako")
        source_file = File.join(File.dirname(bin_path), 'source')
        if File.exist?(source_file) && File.read(source_file).strip == 'tebako' && File.executable?(bin_path)
          executables << 'metanorma'
        end
      end

      executables.to_a.sort
    end

    def remove_obsolete_shims(valid_executables)
      Dir.glob(File.join(@shims_dir, '*')).each do |shim_path|
        shim_name = File.basename(shim_path)
        File.delete(shim_path) unless valid_executables.include?(shim_name)
      end
    end

    def shim_content(_executable_name)
      <<~SHIM
        #!/bin/bash
        set -e

        export MNENV_ROOT="${MNENV_ROOT:-$HOME/.mnenv}"

        # Resolve version and source using mnenv resolver
        VERSION="$("$MNENV_ROOT/lib/mnenv/resolver" "version")"
        SOURCE="$("$MNENV_ROOT/lib/mnenv/resolver" "source")"

        if [ -z "$VERSION" ]; then
          echo "mnenv: version not set or invalid" >&2
          echo "Set a version with: mnenv global <version> or mnenv local <version>" >&2
          exit 1
        fi

        if [ -z "$SOURCE" ]; then
          echo "mnenv: source not set or invalid" >&2
          exit 1
        fi

        # Determine executable path based on source
        if [ "$SOURCE" = "tebako" ]; then
          # Tebako: single self-contained binary
          EXECUTABLE="$MNENV_ROOT/versions/$VERSION/metanorma"
        else
          # Gemfile: binstub from bundle install
          EXECUTABLE="$MNENV_ROOT/versions/$VERSION/bin/$executable_name"
        fi

        if [ ! -f "$EXECUTABLE" ]; then
          echo "mnenv: $executable_name not installed for version $VERSION (source: $SOURCE)" >&2
          echo "Install it with: mnenv install $VERSION --source $SOURCE" >&2
          exit 1
        fi

        exec "$EXECUTABLE" "$@"
      SHIM
    end
  end
end
