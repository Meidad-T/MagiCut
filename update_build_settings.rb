require 'xcodeproj'

project_path = 'MagiCut.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['INFOPLIST_KEY_NSPhotoLibraryUsageDescription'] = 'We need access to your photos to edit subjects and backgrounds.'
  config.build_settings['INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription'] = 'We need access to save edited photos to your library.'
end

project.save
puts "Successfully updated build settings."
