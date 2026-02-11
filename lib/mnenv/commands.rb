# frozen_string_literal: true

module Mnenv
  autoload :GemfileCommand, 'mnenv/commands/gemfile_command'
  autoload :SnapCommand, 'mnenv/commands/snap_command'
  autoload :HomebrewCommand, 'mnenv/commands/homebrew_command'
  autoload :ChocolateyCommand, 'mnenv/commands/chocolatey_command'
end
