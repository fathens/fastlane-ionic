module Fastlane
  module Actions
    class IosBuildAction < Action
      def self.run(params)
        keychain(params[:cert_path], params[:p12_path])
        sh("cordova platform add ios")
        sh("cordova prepare ios")
        provisioning(params[:profile_path])
        sh("cordova build ios --release --device")
      end

      def self.keychain(cert_path, p12_path)
        keychain_name = sh("security default-keychain").match(/.*\/([^\/]+)\"/)[1]
        puts "Using keychain: #{keychain_name}"
        keychain = Pathname('~').expand_path/'Library'/'Keychains'/keychain_name

        FastlaneCore::KeychainImporter.import_file(cert_path.to_s, keychain.to_s)
        FastlaneCore::KeychainImporter.import_file(p12_path.to_s, keychain.to_s,
          certificate_password: ENV["IOS_DISTRIBUTION_KEY_PASSWORD"]
        )
      end

      def self.provisioning(profile_path)
        profile = FastlaneCore::ProvisioningProfile.parse profile_path
        UI.message "Using profile: #{profile}"

        dir = Pathname('~').expand_path/'Library'/'MobileDevice'/'Provisioning Profiles'
        FileUtils.mkdir_p dir
        FileUtils.copy profile_path, dir/"#{profile['UUID']}.mobileprovision"

        (Pathname('platforms')/'ios'/'cordova'/'build.xcconfig').open('a') { |f|
          f.puts "DEVELOPMENT_TEAM = #{profile['TeamIdentifier'].first}"
          f.puts "PROVISIONING_PROFILE_SPECIFIER = #{profile['UUID']}"
        }
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "iOS Build"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :cert_path,
          description: "Path to distribution certificate",
          optional: false,
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :p12_path,
          description: "Path to distribution certificate key",
          optional: false,
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :profile_path,
          description: "Path to provisioning profile path",
          optional: false,
          is_string: false
          )
        ]
      end

      def self.authors
        ["Sawatani"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
