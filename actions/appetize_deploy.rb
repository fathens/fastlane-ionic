module Fastlane
  module Actions
    class AppetizeDeployAction < Action
      def self.run(params)
        platform = params[:platform] || ENV["FASTLANE_PLATFORM_NAME"]
        public_key = get_public_key(platform, params[:api_token], params[:package_id])
        zipfile = mk_zipfile(platform, params[:path])
        begin
          upload(platform, zipfile, params[:api_token], params[:notes_path], public_key)
        ensure
          zipfile.delete if zipfile.exist?
        end
      end

      def self.upload(platform, zipfile, api_token, notes_path, public_key)
        query = {
          platform => platform,
          file => UploadIO.new(zipfile, 'application/zip')
        }
        note = notes_path.read if notes_path
        query[:note] = note if !(note || '').empty?

        uri = URI.parse("https://#{api_token}@api.appetize.io/v1/apps/#{public_key}")
        res = Net::HTTP.start(uri.host, uri.port) { |http|
          http.use_ssl = true
          Net::HTTP::Post::Multipart.new(uri.path, query)
          JSON.parse(http.request(req).body)
        }

        puts JSON.pretty_generate(res)
        res['publicKey']
      end

      def self.get_public_key(platform, api_token, package_id, next_key = nil)
        url = "https://#{api_token}@api.appetize.io/v1/apps"
        url = "#{url}?nextKey=#{next_key}" if next_key

        uri = URI.parse(url)
        res = Net::HTTP.start(uri.host, uri.port) { |http|
          http.use_ssl = true
          req = Net::HTTP::Get.new(url.path)
          JSON.parse(http.request(req).body)
        }

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

      def mk_zipfile(platform, path)
        if !path then
          platform_dir = Pathname.pwd.realpath/'platform'/platform
          if platform == 'android' then
            path = platform_dir/'build'/'outputs'/'apk'/'android-release.apk'
          else
            path = Pathname.glob(platform_dir/'build'/'emulator'/"*.app").first
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
          description: "Appetize.io api token",
          optional: false,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :package_id,
          description: "Android Package or iOS Bundle",
          optional: false,
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
