module Fastlane
  module Actions
    class IosBuildAction < Action
      def self.run(params)
        keychain(params[:certificate_path])
        sh("cordova platform add ios")
        sh("cordova prepare ios")
        provisioning(params[:profile_path])
        sh("cordova build ios --release")
      end

      def self.keychain(certificate_path)
        if is_ci?
          keychainName = sh("security default-keychain").match(/.*\/([^\/]+)\"/)[1]
          puts "Using keychain: #{keychainName}"
          import_certificate(
            keychain_name: keychainName,
            certificate_path: certificate_path,
            certificate_password: ENV["IOS_DISTRIBUTION_KEY_PASSWORD"]
          )
        end
      end

      def self.provisioning(profile_path)
        profile = FastlaneCore::ProvisioningProfile.parse profile_path
        UI.message "Using profile: #{profile}"
        signId = "iPhone Distribution: #{profile['TeamName']} (#{profile['TeamIdentifier'].first})"

        open(dirPlatform/'cordova'/'build-extras.xcconfig', 'a') { |f|
          f.puts "CODE_SIGN_IDENTITY[sdk=iphoneos*] = #{signId}"
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
          FastlaneCore::ConfigItem.new(key: :certificate_path,
          description: "Path to distribution certificate",
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