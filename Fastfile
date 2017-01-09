puts "vertion: 0.0.1"

require 'pathname'

fastlane_version "2.6.0"

into_mode

$PROJECT_DIR = Pathname('..').realpath

def dirPlatform
  $PROJECT_DIR/'platforms'/ENV["FASTLANE_PLATFORM_NAME"]
end

def persistent(*paths)
  ($PROJECT_DIR/'fastlane'/'persistent'/ENV["FASTLANE_PLATFORM_NAME"]).join(*paths)
end

def into_platform &block
  dir = dirPlatform/'fastlane'
  FileUtils.mkdir_p dir
  Dir.chdir(dir) do
    block.call
  end
end

def is_release?
  ["release"].include? ENV['BUILD_MODE']
end

def clean
  def del(*path)
    target = $PROJECT_DIR.join(*path)
    if target.exist? then
      if target.directory? then
        if !(target/'.keep').exist? then
          puts "Deleting dir: #{target.realpath}"
          FileUtils.rm_rf target
        end
      else
        if !Pathname("#{target.to_s}.keep").exist? then
          puts "Deleting file: #{target.realpath}"
          target.delete
        end
      end
    end
  end
  del('config.xml')
  del('resources', ENV["FASTLANE_PLATFORM_NAME"])
  del('platforms')
  del('plugins')
  del('www')
end

platform :ios do
  lane :clean do
    clean
  end

  lane :build do
    cordova_prepare(app_id: ENV["APP_IDENTIFIER"] = ENV['IOS_BUNDLE_ID'])

    into_platform do
      recreate_schemes(
        project: "#{ENV["APPLICATION_DISPLAY_NAME"]}.xcodeproj"
      )
    end

    if is_ci?
      keychainName = sh("security default-keychain").match(/.*\/([^\/]+)\"/)[1]
      puts "Using keychain: #{keychainName}"
      import_certificate keychain_name: keychainName, certificate_path: persistent("Distribution.p12").to_s, certificate_password: ENV["IOS_DISTRIBUTION_KEY_PASSWORD"]
    end

    profile_path = is_release? ? persistent('Profile_AppStore.mobileprovision') : persistent('Profile_AdHoc.mobileprovision')
    profile = FastlaneCore::ProvisioningProfile.parse profile_path
    UI.message "Using profile: #{profile}"
    signId = "iPhone Distribution: #{profile['TeamName']} (#{profile['TeamIdentifier'].first})"

    open(dirPlatform/'cordova'/'build-extras.xcconfig', 'a') { |f|
      f.puts "CODE_SIGN_IDENTITY[sdk=iphoneos*] = #{signId}"
    }

    system('cordova build ios --release')

    if is_ci? then
      ipa_path = dirPlatform/"#{ENV["APPLICATION_DISPLAY_NAME"]}.ipa"
      case ENV['BUILD_MODE']
      when "beta", "debug"
        deploy_beta(path: ipa_path)

      when "release"
        note_path = release_note(line_format: '%s')

        pilot(
        app_identifier: ENV['APP_IDENTIFIER'],
        ipa: ipa_path,
        skip_submission: true,
        distribute_external: false,
        changelog: File.open(note_path).read
        )
      end
    end
  end
end

platform :android do
  lane :clean do
    clean
  end

  lane :build do
    cordova_prepare(app_id: ENV['ANDROID_GOOGLEPLAY_PACKAGE_NAME'])

    android_build(
    keystore: persistent('keystore'),
    multi_apks: is_release?,
    sdks: [
      'platform-tools',
      'tools',
      'android-23',
      'extra-google-m2repository',
      'extra-android-support',
      'extra-android-m2repository',
      'build-tools'
    ])

    if is_ci? then
      dirApk = dirPlatform/'build'/'outputs'/'apk'
      case ENV['BUILD_MODE']
      when "beta", "debug"
        deploy_beta(path: dirApk/'android-release.apk')

      when "release"
        ['armv7', 'x86'].each do |arch|
          begin
            supply(
            apk: (dirApk/"android-#{arch}-release.apk").to_s,
            package_name: ENV['ANDROID_GOOGLEPLAY_PACKAGE_NAME'],
            track: 'beta',
            skip_upload_metadata: true,
            skip_upload_images: true,
            skip_upload_screenshots: true,
            issuer: ENV['ANDROID_GOOGLEPLAY_SERVICE_ACCOUNT_EMAIL'],
            key: persistent('service_account_key.p12')
            )
          rescue => ex
            puts ex.message
          end
        end
      end
    end
  end
end

after_all do
  if ENV["BUILD_NUM"] then
    git_tag(
    username: ENV['GITHUB_USERNAME'],
    token: ENV['GITHUB_OAUTH_TOKEN'],
    tag_name: ['deployed', ENV["FASTLANE_PLATFORM_NAME"], ENV['BUILD_MODE'], ENV["BUILD_NUM"]].join('/')
    )
  end
end
