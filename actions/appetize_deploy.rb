module Fastlane
  module Actions
    class AppetizeDeployAction < Action
      def self.run(params)
        public_key = get_public_key(params[:platform], params[:api_token], params[:package_id])
        zipfile = mk_zipfile(platform, params[:path])
        begin
          upload(platform, zipfile, api_token, params[:notes_path], public_key)
        ensure
          zipfile.delete if zipfile.exist? && zipfile.to_s.end_with?(".zip")
        end
      end

      def self.upload(platform, zipfile, api_token, notes_path, public_key)
        require 'net/http/post/multipart'

        query = {
          platform: platform,
          file: UploadIO.new(zipfile.to_s, 'application/zip')
        }
        note = notes_path.read if notes_path
        query[:note] = note if !(note || '').empty?

        uri = URI.parse("https://api.appetize.io/v1/apps/#{public_key}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Post::Multipart.new(uri.path, query)
        req.basic_auth(api_token, nil)

        UI.message "Uploading: #{query}"
        res = JSON.parse(http.request(req).body)

        res['publicKey']
      end

      def self.get_public_key(platform, api_token, package_id, next_key = nil)
        uri = URI.parse("https://api.appetize.io/v1/apps")
        uri.query = URI.encode_www_form({ nextKey: next_key }) if next_key

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Get.new(uri.path)
        req.basic_auth(api_token, nil)
        res = JSON.parse(http.request(req).body)

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
            nil
          end
        end
      end

      def self.mk_zipfile(platform, path)
        if !path then
          platform_dir = Pathname.pwd.realpath/'platforms'/platform
          if platform == 'android' then
            path = platform_dir/'build'/'outputs'/'apk'/'android-release.apk'
          else
            regex = platform_dir/'build'/'emulator'/'*.app'
            if Pathname.glob(regex).empty? then
              UI.message "Because runs on simulator, we need to rebuild."
              sh("cordova build ios --emulator")
            end
            path = Pathname.glob(regex).first
          end
        end
        path.file? ? path : zip_dir(path)
      end

      def self.zip_dir(basedir)
        require_relative '../lib/gem_install'
        GemInstall.req({"rubyzip" => "zip"})

        zipfile = basedir.dirname/"#{basedir.basename}.zip"
        Zip::File.open(zipfile, Zip::File::CREATE) do |zip|
          Pathname.glob(basedir/'**'/'*') do |file|
            zip.add(file.relative_path_from(basedir.dirname), file) if file.file?
          end
        end
        zipfile.realpath
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Deploy app to Appetize.io"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :api_token,
          env_name: 'APPETIZE_API_TOKEN',
          description: "Appetize.io api token",
          optional: true,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :package_id,
          env_name: 'APP_IDENTIFIER',
          description: "Android Package or iOS Bundle",
          optional: true,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :path,
          description: "Source path to update",
          optional: true,
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :notes_path,
          description: "Release notes path",
          optional: true,
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :platform,
          env_name: 'FASTLANE_PLATFORM_NAME',
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
        [:android, :ios].include? platform
      end
    end
  end
end
