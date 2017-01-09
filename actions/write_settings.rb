module Fastlane
  module Actions
    class WriteSettingsAction < Action
      def self.run(params)
        require 'json'

        src = File.join('src', 'settings.json')
        target = File.join('www', 'settings.json')
        if File.exist?(src) then
          rewrite(src, target)
        end
      end

      def self.rewrite(src, target)
        settings = nil
        File.open(src) do |file|
          settings = JSON.load(file)
        end

        settings.each do |key, name|
          m = /^\${(\w+)}$/.match name
          if m && ENV.has_key?(m[1]) then
            settings[key] = ENV[m[1]]
          end
        end

        puts "Rewriting #{target}"
        File.write(target, JSON.pretty_generate(settings))
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Write settings file"
      end

      def self.available_options
        []
      end

      def self.authors
        ["Sawatani"]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
