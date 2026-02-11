# frozen_string_literal: true

module Mnenv
  class InstallerFactory
    def self.create(version, source:)
      case source.to_s
      when 'gemfile'
        Installers::GemfileInstaller.new(version, source: source)
      when 'tebako'
        Installers::TebakoInstaller.new(version, source: source)
      else
        raise Installer::InstallationError,
              "Unknown source: #{source}. Use: gemfile or tebako"
      end
    end
  end
end
