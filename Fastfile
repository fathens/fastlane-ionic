puts "version: 0.0.1"

require 'pathname'

fastlane_version "2.6.0"

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

before_all do |lane, options|
  clean if options[:clean]
  if lane != :upload_persistent then
    begin
      s3_persistent(command: 'download')
    rescue => ex
      raise ex if is_ci?
      print "S3 Persistent is not found. Do you want to upload now ? (y/n) "
      a = STDIN.gets.chomp
      if a == 'y' || a == 'Y' then
        s3_persistent(command: 'upload')
      else
        raise ex
      end
    end
    into_mode
  end
end

lane :upload_persistent do
  s3_persistent(command: 'upload')
end

platform :ios do
  lane :clean do
    clean
  end

  lane :build do
    cordova_assets(app_id: ENV["APP_IDENTIFIER"] = ENV['IOS_BUNDLE_ID'])

    ios_build(
    certificate_path: persistent("Distribution.p12").to_s,
    profile_path: is_release? ? persistent('Profile_AppStore.mobileprovision') : persistent('Profile_AdHoc.mobileprovision')
    )

    if is_ci? then
      ipa_path = dirPlatform/"#{ENV["APPLICATION_DISPLAY_NAME"]}.ipa"

      if is_release? then
        note_path = release_note(line_format: '%s')

        pilot(
        app_identifier: ENV['APP_IDENTIFIER'],
        ipa: ipa_path,
        skip_submission: true,
        distribute_external: false,
        changelog: File.open(note_path).read
        )
      else
        deploy_beta(path: ipa_path)
      end
    end
  end
end

platform :android do
  lane :clean do
    clean
  end

  lane :build do
    cordova_assets(app_id: ENV['ANDROID_GOOGLEPLAY_PACKAGE_NAME'])

    android_build(
    keystore: persistent('keystore'),
    multi_apks: is_release?
    )

    if is_ci? then
      dirApk = dirPlatform/'build'/'outputs'/'apk'

      if is_release? then
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
      else
        deploy_beta(path: dirApk/'android-release.apk')
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
