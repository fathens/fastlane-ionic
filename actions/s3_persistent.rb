require_relative '../lib/gem_install'

module Fastlane
  module Actions
    class S3PersistentAction < Action
      def self.run(params)
        GemInstall.req("aws-sdk", {"rubyzip" => "zip"})

        basedir = Pathname.pwd.realpath/'fastlane'

        puts "S3Persistent: #{params[:command]}"

        case params[:command]
        when 'upload'
          upload(basedir, params[:bucket], params[:path])
        when 'download'
          download(basedir, params[:bucket], params[:path])
        end
      end

      def self.each_file(dir, &block)
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

      def self.upload(basedir, bucket, dirpath)
        puts "Uploading persistents..."

        buffer = Zip::OutputStream.write_buffer(::StringIO.new('')) { |zip|
          put_entry = lambda do |file|
            puts "Save entry: #{file}"
            zip.put_next_entry(file.relative_path_from basedir)
            file.open { |src|
              zip.write(src.read)
            }
          end

          each_file(basedir/'persistent', &put_entry)
          Pathname.glob(basedir/'.env.*').each(&put_entry)
        }
        s3 = Aws::S3::Client.new
        s3.put_object(
          body: buffer.string,
          bucket: bucket,
          key: "#{dirpath}/persistent.zip"
        )
        puts "Done to upload persistents"
      end

      def self.download(basedir, bucket, dirpath)
        puts "Downloading persistents..."
        s3 = Aws::S3::Client.new
        res = s3.get_object(
          bucket: bucket,
          key: "#{dirpath}/persistent.zip"
        )
        zip = Zip::InputStream.new(res.body)
        while (entry = zip.get_next_entry) do
          target = basedir/entry.name
          puts "Load entry: #{target}"
          FileUtils.mkdir_p target.dirname
          target.open('w') { |dst|
            dst.puts zip.read
          }
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Store persistents for S3"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :command,
          description: "'upload' | 'download'",
          optional: false,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :bucket,
          description: "Bucket name of S3",
          optional: false,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :path,
          description: "Path in S3 to dir which continas archive file",
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
