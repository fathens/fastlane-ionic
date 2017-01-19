puts "version: 0.1.0"

fastlane_version "2.8.0"

$PROJECT_DIR = Pathname('..').realpath

def dirPlatform
  $PROJECT_DIR/'platforms'/ENV["FASTLANE_PLATFORM_NAME"]
end

def persistent(*paths)
  ($PROJECT_DIR/'fastlane'/'persistent'/ENV["FASTLANE_PLATFORM_NAME"]).join(*paths)
end

def is_release?
  ["release"].include? ENV['BUILD_MODE']
end

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

def clean
  del('config.xml')
  del('resources', ENV["FASTLANE_PLATFORM_NAME"])
  del('platforms')
  del('plugins')
  del('www')
end

def check_persistent
  begin
    s3_persistent(command: 'download',
      bucket: ENV['AWS_S3_BUCKET'],
      path: ENV['PROJECT_REPO_SLUG'])
  rescue => ex
    raise ex if is_ci?
    print "S3 Persistent is not found. Do you want to upload now ? (y/n) "
    a = STDIN.gets.chomp
    if a == 'y' || a == 'Y' then
      upload_persistent
    else
      raise ex
    end
  end
end

before_all do |lane, options|
  clean if options[:clean]
  if lane != :upload_persistent then
    check_persistent if !options[:no_persistent]
    into_mode
  end
end

lane :upload_persistent do
  s3_persistent(command: 'upload',
    bucket: ENV['AWS_S3_BUCKET'],
    path: ENV['PROJECT_REPO_SLUG'])
end

platform :ios do
  lane :clean do
    clean
  end

  lane :build do
    cordova_assets(app_id: ENV['IOS_BUNDLE_ID'], version_code: {
      'ios-CFBundleVersion': ENV['BUILD_NUM']
    })

    ios_build(
      develop_cert_path: persistent("Development.p12"),
      distrib_cert_path: persistent("Distribution.p12"),
      develop_cert_password: ENV["IOS_DEVELOPMENT_KEY_PASSWORD"],
      distrib_cert_password: ENV["IOS_DISTRIBUTION_KEY_PASSWORD"],
      develop_profile_path: persistent('Profile_Development.mobileprovision'),
      target_profile_path: is_release? ? persistent('Profile_AppStore.mobileprovision') : persistent('Profile_AdHoc.mobileprovision')
    )
  end
end

platform :android do
  lane :clean do
    clean
  end

  lane :build do
    cordova_assets(app_id: ENV['ANDROID_GOOGLEPLAY_PACKAGE_NAME'], version_code: {
      'android-versionCode': ENV['BUILD_NUM'] ? "#{ENV['BUILD_NUM']}000" : nil
    })

    android_build(
      keystore: persistent('keystore'),
      multi_apks: is_release?
    )
  end
end

platform :mac do
  lane :clean do
    del('www')
  end

  lane :build do
    Dir.chdir($PROJECT_DIR) do
      sh("npm install")
      sh("npm run build")
    end
  end
end

after_all do |lane, options|
  if lane != :upload_persistent then
    if is_ci? then
      if ENV["FASTLANE_PLATFORM_NAME"] == 'mac' then
        deploy_s3site
      else
        if is_release? then
          deploy_store
        else
          begin
            deploy_crashlytics
          rescue => ex
            puts "Failed to upload to Crashlytics Beta: #{ex}"
            puts "Trying to upload to Appetize.io"
            appetize_deploy
          end
        end
      end
    else
      puts "Not on CI, No need to deploy."
    end

    if ENV["BUILD_NUM"] then
      git_tag(
        username: ENV['GITHUB_USERNAME'],
        token: ENV['GITHUB_OAUTH_TOKEN'],
        tag_name: ['deployed', ENV["FASTLANE_PLATFORM_NAME"], ENV['BUILD_MODE'], ENV["BUILD_NUM"]].join('/')
      )
    end
  end
end

def deploy_s3site
  s3_site_deploy(
    src_path: 'www',
    bucket: ENV['S3_SITE_BUCKET'])
end

def deploy_store
  if ENV["FASTLANE_PLATFORM_NAME"] == 'android' then
    Pathname.glob(dirPlatform/'build'/'outputs'/'apk'/'android-*-release.apk').each { |apk|
      supply(
        apk: apk.to_s,
        package_name: ENV['ANDROID_GOOGLEPLAY_PACKAGE_NAME'],
        track: 'beta',
        skip_upload_metadata: true,
        skip_upload_images: true,
        skip_upload_screenshots: true,
        json_key: persistent('service_account_key.json').to_s
      )
    }
  else
    pilot(
      app_identifier: ENV['APP_IDENTIFIER'],
      ipa: Pathname.glob(dirPlatform/'build'/'device'/'*.ipa').first.to_s,
      skip_submission: true,
      distribute_external: false,
      changelog: release_note(line_format: '%s').read
    )
  end
end

def deploy_crashlytics
  if ENV["FASTLANE_PLATFORM_NAME"] == 'android' then
    apk_path = (dirPlatform/'build'/'outputs'/'apk'/'android-release.apk').to_s
  else
    ipa_path = Pathname.glob(dirPlatform/'build'/'device'/'*.ipa').first.to_s
  end

  crashlytics(
    ipa_path: ipa_path,
    apk_path: apk_path,
    api_token: ENV["FABRIC_API_KEY"],
    build_secret: ENV["FABRIC_BUILD_SECRET"],
    notes_path: release_note.to_s,
    groups: ENV["FABRIC_CRASHLYTICS_GROUPS"],
    notifications: false,
    debug: false
  )
end
