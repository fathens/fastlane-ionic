module Fastlane
  module Actions
    class IosBuildAction < Action
      def self.run(params)
        keychain(
          params[:develop_cert_path], params[:develop_cert_password],
          params[:distrib_cert_path], params[:distrib_cert_password])
        sh("cordova platform add ios")
        args = provisioning(params[:target_profile_path], params[:develop_profile_path])
        sh("cordova build ios --release --device #{args}")
      end

      def self.keychain(dev_path, dev_password, dist_path, dist_password)
        keychain_name = sh("security default-keychain").match(/.*\/([^\/]+)\"/)[1]
        UI.message "Using keychain: #{keychain_name}"
        keychain = (Pathname('~').expand_path/'Library'/'Keychains'/keychain_name).to_s

        FastlaneCore::KeychainImporter.import_file(dev_path.to_s, keychain,
          certificate_password: dev_password)
        FastlaneCore::KeychainImporter.import_file(dist_path.to_s, keychain,
          certificate_password: dist_password)
      end

      def self.provisioning(target_profile_path, develop_profile_path)
        dir = Pathname('~').expand_path/'Library'/'MobileDevice'/'Provisioning Profiles'
        FileUtils.mkdir_p dir
        save_profile = lambda do |profile_path|
          profile = FastlaneCore::ProvisioningProfile.parse profile_path
          FileUtils.copy profile_path, dir/"#{profile['UUID']}.mobileprovision"
          profile
        end

        save_profile[develop_profile_path]
        profile = save_profile[target_profile_path]
        UI.message "Using profile: #{profile}"

        {
          provisioningProfile: profile['UUID'],
          developmentTeam: profile['TeamIdentifier'].first
        }.map { |key, value|
          "--#{key}=#{value}"
        }.join(' ')
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "iOS Build"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :develop_cert_path,
          description: "Path to development certificate",
          optional: false,
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :distrib_cert_path,
          description: "Path to distribution certificate",
          optional: false,
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :develop_cert_password,
          description: "Password for development certificate",
          optional: false,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :distrib_cert_password,
          description: "Password for distribution certificate",
          optional: false,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :target_profile_path,
          description: "Path to provisioning profile for use",
          optional: false,
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :develop_profile_path,
          description: "Path to provisioning profile for develoment",
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
