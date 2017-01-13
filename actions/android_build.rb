module Fastlane
  module Actions
    class AndroidBuildAction < Action
      def self.run(params)
        FileUtils.mkdir_p Pathname('~').expand_path/'.android'

        update_sdk
        sh("cordova platform add android")

        config_file = Dir.chdir(Pathname('platforms')/'android') do
          multi_apks(params[:multi_apks])
          keystore(params[:keystore])
        end

        sh("cordova build android --release --device --buildConfig=#{config_file}")
      end

      def self.latest_build_tool
        sh("android list sdk --no-ui --all --extended | grep build-tools").lines.map { |line|
          line.chomp.match(/^.*\"build-tools-(.+)\".*$/)[1]
        }.sort.last
      end

      def self.update_sdk
        require 'rexml/document'
        config = REXML::Document.new(Pathname('config.xml').read)
        platform = config.elements['//platform[@name="android"]']

        build_tools_version = platform&.attribute('build-tools')&.value || latest_build_tool
        api_version = platform&.attribute('api-version')&.value || '24'

        sdks = [
          "android-#{api_version}",
          "platform-tools",
          "tools",
          "build-tools-#{build_tools_version}"
        ]
        sh("echo y | android update sdk -u --filter #{sdks.join ','}")
      end

      def self.keystore(file)
        data = {:android => {:release =>{
          :keystore => file,
          :storePassword => ENV['ANDROID_KEYSTORE_PASSWORD'],
          :alias => ENV['ANDROID_KEYSTORE_ALIAS'],
          :password => ENV['ANDROID_KEYSTORE_ALIAS_PASSWORD']
          }}}

        target = 'build.json'
        puts "Writing #{target}"
        File.write(target, JSON.dump(data))

        File.absolute_path target
      end

      def self.multi_apks(multi)
        key = 'cdvBuildMultipleApks'

        target = 'gradle.properties'
        lines = File.exist?(target) ? File.readlines(target) : []

        File.open(target, 'w+') do |file|
          lines.reject { |line| line.include?(key) }.each do |line|
            file.puts line
          end
          file.puts "#{key}=#{multi}"
        end

        File.absolute_path target
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Android Build"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :keystore,
          description: "Absolute path to keystore",
          optional: false,
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :multi_apks,
          description: "Boolean for build multiple apks",
          optional: false,
          is_string: false
          )
        ]
      end

      def self.authors
        ["Sawatani"]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
