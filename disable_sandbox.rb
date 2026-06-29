require 'xcodeproj'

project_path = 'MagiCut.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  config.build_settings['ENABLE_APP_SANDBOX'] = 'NO'
end

project.save
puts "Successfully disabled App Sandbox."
