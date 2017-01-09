module Fastlane
  module Actions
    class CordovaPrepareAction < Action
      def self.run(params)
          copy_config(params[:app_id])
          npm_build
          mk_platform
          system("cordova prepare #{ENV["FASTLANE_PLATFORM_NAME"]}")
      end

      def self.copy_config(appId)
        template = Pathname('cordova.config.xml')
        target = Pathname('config.xml')
        if template.exist? && !target.exist? then
          FileUtils.copy(template, target)
        end

        puts "Setting App ID '#{appId}' to #{target}"
        require 'rexml/document'
        doc = REXML::Document.new(open(target))

        doc.elements['widget'].attributes['id'] = appId
        File.write(target, doc)
      end

      def self.npm_build
        if !Pathname('www').exist? then
          system("npm install")
          system("npm run ionic:build")
          cache_index
        end
      end

      def self.mk_platform
        dirs = [Pathname('plugins'), Pathname('platforms')/ENV["FASTLANE_PLATFORM_NAME"]]
        if !dirs.all? { |x| x.exist? } then
          dirs.each do |dir|
            puts "Deleting dir: #{dir}"
            FileUtils.rm_rf dir
          end
          Dir.mkdir dirs.first

          system("cordova platform add #{ENV["FASTLANE_PLATFORM_NAME"]}")
        end

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
          system("ionic resources")
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
          optional: false,
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
