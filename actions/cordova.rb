require 'pathname'

module Fastlane
  module Actions
    class CordovaAction < Action
      def self.run(params)
        cordova(params[:plugins] || [])
        ionic
      end

      def self.cordova(plugins)
        dirs = [Pathname('plugins'), Pathname('platforms')/ENV["FASTLANE_PLATFORM_NAME"]]
        if !dirs.all? { |x| x.exist? } then
          dirs.each do |dir|
            puts "Deleting dir: #{dir}"
            FileUtils.rm_rf dir
          end
          Dir.mkdir dirs.first

          system("cordova platform add #{ENV["FASTLANE_PLATFORM_NAME"]}")

          plugins.each do |line|
            system("cordova plugin add #{line}") if line
          end
        end
      end

      def self.ionic
        dir = Pathname('resources')
        if !(dir/ENV["FASTLANE_PLATFORM_NAME"]).exist? then
          use_png(dir, 'icon')
          use_png(dir, 'splash')
          system("ionic resources")
        end
      end

      def self.use_png(dir, prefix)
        src = dir/"#{prefix}-#{ENV["FASTLANE_PLATFORM_NAME"]}.png"
        if src.exist? then
          FileUtils.copy(src, dir/"#{prefix}.png")
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Cordova prepare"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :plugins,
          description: "Array of plugins",
          optional: true,
          is_string: false
          )
        ]
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
