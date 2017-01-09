require 'pathname'

fastlane_version "1.39.0"

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

def adjust_buildnum(offset)
  src = ENV['BUILD_NUM'] || '0'
  ENV['BUILD_NUM'] = "#{Integer(src) + offset}"
  puts "Adjusted BuildNum: #{ENV['BUILD_NUM']}"
end

def is_release?
  ["release"].include? ENV['BUILD_MODE']
end

def copy_config
  src = $PROJECT_DIR/'cordova.config.xml'
  dst = $PROJECT_DIR/'config.xml'
  if src.exist? && !dst.exist? then
    FileUtils.copy(src, dst)
  end
end

def createWWW
  if !($PROJECT_DIR/'www').exist? then
    Dir.chdir($PROJECT_DIR) do
      sh("npm run custom_icons")
      sh("npm run ionic:build")
    end
    write_settings
    cache_index
  end
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

def prepare(app_id)
  into_mode

  copy_config

  set_app_id(id: app_id)

  adjust_buildnum(0)

  createWWW

  cordova
end

lane :prepare_serve do
  into_mode
  write_settings
end

platform :ios do
  lane :clean do
    clean
  end

  lane :build do
    prepare(ENV["APP_IDENTIFIER"] = ENV['IOS_BUNDLE_ID'])
    sh('cordova prepare ios')

    if is_ci?
      keychainName = sh("security default-keychain").match(/.*\/([^\/]+)\"/)[1]
      puts "Using keychain: #{keychainName}"
      import_certificate keychain_name: keychainName, certificate_path: persistent("Distribution.p12").to_s, certificate_password: ENV["IOS_DISTRIBUTION_KEY_PASSWORD"]
    end

    into_platform do
      recreate_schemes(
        project: "#{ENV["APPLICATION_DISPLAY_NAME"]}.xcodeproj"
      )

      if ENV["BUILD_NUM"] != nil then
        increment_build_number(
        build_number: ENV["BUILD_NUM"]
        )
      end

      sigh(
      app_identifier: ENV['APP_IDENTIFIER'],
      adhoc: !is_release?
      )

      profile = FastlaneCore::ProvisioningProfile.parse lane_context[:SIGH_PROFILE_PATH]
      UI.message "Using profile: #{profile}"
      signId = "iPhone Distribution: #{profile['TeamName']} (#{profile['TeamIdentifier'].first})"

      open(dirPlatform/'cordova'/'build-extras.xcconfig', 'a') { |f|
        f.puts "CODE_SIGN_IDENTITY[sdk=iphoneos*] = #{signId}"
      }

      gym(
      scheme: ENV["APPLICATION_DISPLAY_NAME"],
      configuration: "Release",
      include_bitcode: false,
      codesigning_identity: signId,
      xcargs: {
        PROVISIONING_PROFILE_SPECIFIER: profile['Name'],
      }.map { |k, v| "#{k.to_s.shellescape}='#{v}'" }.join(' ')
      )

      if is_ci? then
        case ENV['BUILD_MODE']
        when "beta", "debug"
          release_note
          deploy_beta(dirPlatform/"#{ENV["APPLICATION_DISPLAY_NAME"]}.ipa")

        when "release"
          release_note(line_format: '%s')

          pilot(
          app_identifier: ENV['APP_IDENTIFIER'],
          skip_submission: true,
          distribute_external: false,
          changelog: File.open(ENV['RELEASE_NOTE_PATH']).read
          )
        end
      end
    end
  end
end

platform :android do
  lane :clean do
    clean
  end

  lane :build do
    prepare(ENV['ANDROID_GOOGLEPLAY_PACKAGE_NAME'])

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
        release_note
        deploy_beta(dirApk/'android-release.apk')

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

def deploy_beta(path)
  case ENV["FASTLANE_PLATFORM_NAME"]
  when "ios"
    ipa_path = path.to_s
  when "android"
    apk_path = path.to_s
  else
    raise "Unsupported platform: #{ENV["FASTLANE_PLATFORM_NAME"]}"
  end
  crashlytics(
  ipa_path: ipa_path,
  apk_path: apk_path,
  api_token: ENV["FABRIC_API_KEY"],
  build_secret: ENV["FABRIC_BUILD_SECRET"],
  notes_path: ENV["RELEASE_NOTE_PATH"],
  groups: ENV["FABRIC_CRASHLYTICS_GROUPS"],
  notifications: false,
  debug: false
  )
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