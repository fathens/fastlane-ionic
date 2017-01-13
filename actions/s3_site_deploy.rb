require_relative '../lib/gem_install'

module Fastlane
  module Actions
    class S3SiteDeployAction < Action
      def self.run(params)
        GemInstall.req("aws-sdk")

        upload_dir(params[:src_path], params[:bucket])
      end

      def self.upload_dir(src_dir, bucket_name, dst_dir = '')
        src_dir = Pathname(src_dir.to_s) unless src_dir.is_a? Pathname
        src_dir = src_dir.realpath

        deleting_keys = []
        uploaded_keys = []

        bucket = Aws::S3::Resource.new().bucket(bucket_name)
        upload = lambda do |key, local_file|
          bucket.object(key).upload_file(local_file)
          UI.message "Upload #{key}"
        end
        delete = lambda do |key|
          bucket.object(key).delete
          UI.message "Delete #{key}"
        end

        bucket.objects.each do |summary|
          key = summary.key
          local_file = src_dir/key
          if local_file.exist? then
            diff = summary.last_modified.utc <=> local_file.mtime.utc
            upload[key, local_file] if diff < 0
            uploaded_keys.push key
          else
            deleting_keys.push key
          end
        end
        each_file(src_dir) do |file|
          key = file.relative_path_from(src_dir).to_s
          if !uploaded_keys.include? key then
            upload[key, file]
          end
        end
        deleting_keys.each(&delete)

        UI.message "Done to deploy S3 site: #{bucket_name}"
      end

      def self.each_file(dir, &block)
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
        "Web site deploy for S3"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :src_path,
          description: "Source directory for deploy",
          optional: false,
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :bucket,
          description: "S3 bucket name for deploy",
          optional: false,
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
