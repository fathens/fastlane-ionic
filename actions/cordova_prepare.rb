module Fastlane
  module Actions
    class CordovaPrepareAction < Action
      def self.run(params)
        copy_config(params[:app_id])
        npm_build
        resources
      end

      def self.copy_config(appId)
        template = Pathname('cordova.config.xml')
        target = Pathname('config.xml')
        if template.exist? && !target.exist? then
          FileUtils.copy(template, target)
        end

        if appId then
          puts "Setting App ID '#{appId}' to #{target}"
          require 'rexml/document'
          doc = REXML::Document.new(open(target))

          doc.elements['widget'].attributes['id'] = appId
          File.write(target, doc)
        end
      end

      def self.npm_build
        if !Pathname('www').exist? then
          sh("npm install")
          sh("npm run ionic:build")
        end
      end

      def self.resources
        res_dir= Pathname('resources')
        use_png = lambda { |prefix|
          src = res_dir/"#{prefix}-#{ENV["FASTLANE_PLATFORM_NAME"]}.png"
          if src.exist? then
            FileUtils.copy(src, res_dir/"#{prefix}.png")
          end
        }
        if !(res_dir/ENV["FASTLANE_PLATFORM_NAME"]).exist? then
          use_png['icon']
          use_png['splash']
          sh("ionic resources #{ENV["FASTLANE_PLATFORM_NAME"]}")
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Set app ID for config.xml"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :app_id,
          description: "App ID for config.xml",
          optional: true,
          is_string: true
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
