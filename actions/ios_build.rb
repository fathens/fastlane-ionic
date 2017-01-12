module Fastlane
  module Actions
    class IosBuildAction < Action
      def self.run(params)
        keychain(
          params[:develop_cert_path], params[:develop_cert_password],
          params[:distrib_cert_path], params[:distrib_cert_password])
        sh("cordova platform add ios")
        sh("cordova prepare ios")
        provisioning(params[:target_profile_path], params[:develop_profile_path])
        sh("cordova build ios --release --device")
      end

      def self.keychain(dev_path, dev_password, dist_path, dist_password)
        keychain_name = sh("security default-keychain").match(/.*\/([^\/]+)\"/)[1]
        puts "Using keychain: #{keychain_name}"
        keychain = (Pathname('~').expand_path/'Library'/'Keychains'/keychain_name).to_s

        FastlaneCore::KeychainImporter.import_file(dev_path.to_s, keychain,
          certificate_password: dev_password)
        FastlaneCore::KeychainImporter.import_file(dist_path.to_s, keychain,
          certificate_password: dist_password)
      end

      def self.provisioning(target_profile_path, develop_profile_path)
        profile = FastlaneCore::ProvisioningProfile.parse target_profile_path
        UI.message "Using profile: #{profile}"

        dev_uuid = FastlaneCore::ProvisioningProfile.parse(develop_profile_path)['UUID']

        dir = Pathname('~').expand_path/'Library'/'MobileDevice'/'Provisioning Profiles'
        FileUtils.mkdir_p dir
        FileUtils.copy target_profile_path, dir/"#{profile['UUID']}.mobileprovision"
        FileUtils.copy develop_profile_path, dir/"#{dev_uuid}.mobileprovision"

        config_values = {
          "DEVELOPMENT_TEAM" => profile['TeamIdentifier'].first,
          "PROVISIONING_PROFILE" => profile['UUID']
        }
        config_values.keys.each { |key|
          [].each { |sub|
            config_values["#{key}[#{sub}]"] = config_values[key]
          }
        }
        rewrite(Pathname('platforms')/'ios'/'cordova'/'build.xcconfig', config_values)
      end

      def self.rewrite(xcconfig, config_values)
        xcconfig_tmp = Pathname("#{xcconfig}.tmp")

        xcconfig.open('r') { |src|
          xcconfig_tmp.open('w') { |dst|
            src.each_line { |line|
              found = config_values.keys.find_index { |key|
                line.start_with? "#{key} ="
              }
              dst.puts line if !found
            }
            dst.puts "", "// Code Signing"
            config_values.each { |key, value|
              dst.puts "#{key} = #{value}"
            }
          }
        }
        xcconfig_tmp.rename xcconfig
        UI.message "Wrote #{xcconfig}"
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "iOS Build"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :develop_cert_path,
          description: "Path to development certificate",
          optional: false,
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :distrib_cert_path,
          description: "Path to distribution certificate",
          optional: false,
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :develop_cert_password,
          description: "Password for development certificate",
          optional: false,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :distrib_cert_password,
          description: "Password for distribution certificate",
          optional: false,
          is_string: true
          ),
          FastlaneCore::ConfigItem.new(key: :target_profile_path,
          description: "Path to provisioning profile for use",
          optional: false,
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :develop_profile_path,
          description: "Path to provisioning profile for develoment",
          optional: false,
          is_string: false
          )
        ]
      end

      def self.authors
        ["Sawatani"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
