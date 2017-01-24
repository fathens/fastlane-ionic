module Fastlane
  module Actions
    class BabelEs5Action < Action
      def self.run(params)
        babel(Pathname('www')/'build'/'main.js')
        add_runtime(Pathname('node_modules')/'regenerator-runtime'/'runtime.js')
      end

      def self.babel(src)
        tmp = Pathname('es5.js')
        sh('npm install babel-cli babel-preset-es2015 babel-preset-stage-0')
        sh("babel --presets=es2015,stage-0 -o #{tmp} #{src}")
        tmp.rename src

        jsmap = Pathname("#{src}.map")
        jsmap.delete if jsmap.exist?
      end

      def self.add_runtime(target_src)
        www = Pathname('www')
        target_dst = www/'babel-es5'/File.basename(target_src)
        FileUtils.mkdir_p target_dst.dirname
        FileUtils.copy target_src, target_dst
        target = target_dst.relative_path_from(www).to_s

        src = www/'index.html'
        lines = []
        open(src, 'r') do |f|
          f.each_line { |line|
            lines.push line
            /(^.+[\"\'])build\/polyfills\.js([\"\'].+$)/.match(line) do |m|
              lines.push "#{m[1]}#{target}#{m[2]}"
            end
          }
        end
        open(src, 'w') do |f|
          f.puts lines
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Transpile es6 to es5 by babel"
      end

      def self.available_options
        [
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
