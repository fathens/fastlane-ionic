module Fastlane
  module Actions
    class AppetizePublickeyAction < Action
      def self.run(params)
        require_relative '../lib/gem_install'
        GemInstall.req("httparty")

        platform = params[:platform] || ENV["FASTLANE_PLATFORM_NAME"]
        retrieve(platform, params[:api_token], params[:package_id])
      end

      def self.retrieve(platform, api_token, package_id, next_key = nil)
        url = "https://#{api_token}@api.appetize.io/v1/apps"
        url = "#{url}?nextKey=#{next_key}" if next_key

        res = JSON.parse(HTTParty.get(url).body)

        found = res['data'].find { |app|
          app['platform'] == platform && app['bundle'] == package_id
        }
        if found then
          UI.message "Found Appetize App: #{found}"
          found['publicKey']
        else
          if res['hasMore'] then
            retrieve(platform, api_token, package_id, res['nextKey'])
          else
            UI.message "Not found Appetize App on '#{platform}': #{package_id}"
          end
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
          FastlaneCore::ConfigItem.new(key: :api_token,
          description: "Appetize.io api token",
          optional: false,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :package_id,
          description: "Android Package or iOS Bundle",
          optional: false,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :platform,
          description: "Platform name for search",
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
