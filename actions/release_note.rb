module Fastlane
  module Actions
    class ReleaseNoteAction < Action
      def self.run(params)
        notes = logs(params[:line_format]).join("\n")

        UI.message "#### RELEASE_NOTE ####\n" + notes
        if !notes.empty? then
          target = Pathname('.release_note')
          target.write notes
          target.realpath.to_s
        end
      end

      def self.logs(format)
        format ||= '[%h] %s'

        last = last_tag
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

      def self.last_tag
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
        prefix = "deployed/#{ENV['FASTLANE_PLATFORM_NAME']}/#{ENV['BUILD_MODE']}/"
        num = sh("git tag -l | grep '#{prefix}' || echo").split("\n").map { |line|
          line.match(/.*\/([0-9]+)$/)[1].to_i
        }.select { |n|
          n < ENV['BUILD_NUM'].to_i
        }.max
        "#{prefix}#{num}"
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