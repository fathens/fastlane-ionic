module Fastlane
  module Actions
    class CordovaAssetsAction < Action
      def self.run(params)
        copy_config(params[:app_id], params[:version_code])
        resources
      end

      def self.copy_config(appId, versionCode)
        template = Pathname('cordova.config.xml')
        target = Pathname('config.xml')
        if !template.exist? then
          UI.message "Template is not found: #{template}"
          return
        end
        if target.exist? then
          UI.message "Target is already here: #{target}"
          return
        end

        require 'rexml/document'
        doc = REXML::Document.new(open(template))
        widget = doc.elements['widget']

        if ENV['BUILD_MODE'] == "release" then
          widget.elements.delete("plugin[@name='cordova-plugin-console']")
        end

        if appId then
          ENV["APP_IDENTIFIER"] = appId
          widget.attributes['id'] = appId
          UI.message "Setting App ID: '#{appId}' on #{target}"
        end
        if versionCode then
          versionCode.each { |key, value|
            if value then
              UI.message "Setting '#{key}' = '#{value}' on #{target}"
              widget.attributes[key.to_s] = value
            end
          }
        end

        target.write doc
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
        "Configure assets for Cordova building"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :app_id,
          description: "App ID for config.xml",
          optional: true,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :version_code,
          description: "versionCode for config.xml",
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
