module Fastlane
  module Actions
    class ReleaseNoteAction < Action
      def self.run(params)
        platform = params[:platform] || ENV['FASTLANE_PLATFORM_NAME']
        build_mode = params[:build_mode] || ENV['BUILD_MODE']
        build_num = (params[:build_num] || ENV['BUILD_NUM']).to_i

        notes = logs(platform, build_mode, build_num, params[:line_format]).join("\n")

        UI.message "#### RELEASE_NOTE ####\n" + notes
        target = Pathname('.release_note')
        target.write notes
        target.realpath
      end

      def self.logs(platform, build_mode, build_num, format)
        format ||= '[%h] %s'

        last = last_tag(platform, build_mode, build_num)
        logs = []
        obj = CommitObj.new('HEAD')
        if last
          last_sha = CommitObj.new(last).sha
          while obj && obj.sha != last_sha
            parents = obj.parents.sort_by(&:timestamp).reverse
            logs << obj.log(format) if parents.size < 2
            obj = parents.first
          end
        else
          logs << obj.log(format)
        end
        logs
      end

      def self.last_tag(platform, build_mode, build_num)
        retry_count = 3
        begin
          sh("git fetch")
        rescue
          retry_count -= 1
          if 0 < retry_count then
            retry
          else
            raise
          end
        end
        prefix = ['deployed', platform, build_mode].join('/') + '/'
        num = sh("git tag -l | grep '#{prefix}' || echo").lines.map { |line|
          line.chomp.match(/.*\/([0-9]+)$/)
        }.compact.map { |m|
          m[1].to_i
        }.select { |n|
          n < build_num
        }.max
        num ? prefix + num.to_s : 'HEAD'
      end

      class CommitObj
        def initialize(name)
          @name = name
        end

        def sha
          log('%H')
        end

        def parents
          log('%P').split.map { |x| CommitObj.new(x) }
        end

        def timestamp
          log('%at').to_i
        end

        def log(format)
          Action.sh("git log #{@name} -n1 --format='#{format}'").strip
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Git logs from previous deploy"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :line_format,
          description: "Format of each line. default: '[%h] %s'",
          optional: true,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :platform,
          env_name: 'FASTLANE_PLATFORM_NAME',
          description: "Platform",
          optional: true,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :build_mode,
          env_name: 'BUILD_MODE',
          description: "Build Mode",
          optional: true,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :build_num,
          env_name: 'BUILD_NUM',
          description: "Build Number",
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