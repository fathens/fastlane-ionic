module Fastlane
  module Actions
    class DeployBetaAction < Action
      def self.run(params)
          path = params[:path]
          case ENV["FASTLANE_PLATFORM_NAME"]
          when "ios"
            ipa_path = path.to_s
          when "android"
            apk_path = path.to_s
          else
            raise "Unsupported platform: #{ENV["FASTLANE_PLATFORM_NAME"]}"
          end
          crashlytics(
          ipa_path: ipa_path,
          apk_path: apk_path,
          api_token: ENV["FABRIC_API_KEY"],
          build_secret: ENV["FABRIC_BUILD_SECRET"],
          notes_path: release_note,
          groups: ENV["FABRIC_CRASHLYTICS_GROUPS"],
          notifications: false,
          debug: false
          )
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Push tag to Github"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :path,
          description: "Path to APK/IPA file",
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
