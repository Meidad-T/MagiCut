require 'xcodeproj'

project_path = 'MagiCut.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'MagiCut/MagiCut.entitlements'
  end
end

project.save
puts "Successfully added CODE_SIGN_ENTITLEMENTS to build settings."
