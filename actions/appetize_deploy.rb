module Fastlane
  module Actions
    class AppetizeDeployAction < Action
      def self.run(params)
        platform = params[:platform] || ENV["FASTLANE_PLATFORM_NAME"]
        public_key = get_public_key(platform, params[:api_token], params[:package_id])
        zipfile = mk_zipfile(platform, params[:path], params[:app_name] || ENV['APPLICATION_DISPLAY_NAME'])
        begin
          upload(platform, zipfile, params[:api_token] || ENV["APPETIZE_API_TOKEN"], params[:notes_path], public_key)
        ensure
          zipfile.delete if zipfile.exist?
        end
      end

      def self.upload(platform, zipfile, api_token, notes_path, public_key)
        query = {
          platform: platform,
          file: UploadIO.new(zipfile, 'application/zip')
        }
        note = notes_path.read if notes_path
        query[:note] = note if !(note || '').empty?

        uri = URI.parse("https://#{api_token}@api.appetize.io/v1/apps/#{public_key}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Post::Multipart.new(uri.path, query)
        res = JSON.parse(http.request(req).body)

        puts JSON.pretty_generate(res)
        res['publicKey']
      end

      def self.get_public_key(platform, api_token, package_id, next_key = nil)
        uri = URI.parse("https://#{api_token}@api.appetize.io/v1/apps")
        uri.query = URI.encode_www_form({ nextKey: next_key }) if next_key

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Get.new(uri.path)
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
          end
        end
      end

      def mk_zipfile(platform, path, app_name)
        if !path then
          platform_dir = Pathname.pwd.realpath/'platform'/platform
          if platform == 'android' then
            path = platform_dir/'build'/'outputs'/'apk'/'android-release.apk'
          else
            path = platform_dir/'build'/'emulator'/"#{app_name}.app"
          end
        end

        if !path.exist? && platform == 'ios' then
          puts "Because runs on simulator, we need to rebuild."
          sh("cordova build ios --emulator")
        end

        path.file? ? path : zipdir(path)
      end

      def zip_dir(basedir)
        require_relative '../lib/gem_install'
        GemInstall.req({"rubyzip" => "zip"})

        zipfile = Pathname('.tmp-artifact.zip')
        Zip::File.open(zipfile, Zip::File::CREATE) do |zip|
          each_file(basedir) do |file|
            zip.add(file.relative_path_from(basedir), file)
          end
        end
        zipfile.realpath
      end

      def each_file(dir, &block)
        puts "Searching in #{dir}"
        dir.each_entry { |x|
          e = dir/x
          if e != dir && e != dir.dirname then
            if e.directory? then
              each_file(e, &block)
            elsif e.file? then
              block[e]
            end
          end
        }
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
          ),
          FastlaneCore::ConfigItem.new(key: :app_name,
          env_name: 'APPLICATION_DISPLAY_NAME',
          description: "Application name for display",
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
