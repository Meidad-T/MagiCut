require 'xcodeproj'
require 'fileutils'

project_path = 'MagiCut.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add files helper
def add_files_to_group(project, target, group, path)
  Dir.glob("#{path}/*").each do |file_path|
    next if file_path.include?('.DS_Store')
    
    file_name = File.basename(file_path)
    if File.directory?(file_path)
      # Check if group exists, if not create
      subgroup = group.children.find { |c| c.name == file_name && c.class == Xcodeproj::Project::Object::PBXGroup }
      subgroup ||= group.new_group(file_name, file_name, '<group>')
      add_files_to_group(project, target, subgroup, file_path)
    else
      # It's a file, check if it's already in the group
      file_ref = group.files.find { |f| f.path == file_name }
      unless file_ref
        file_ref = group.new_file(file_name)
        if file_name.end_with?('.swift')
          target.add_file_references([file_ref])
        end
      end
    end
  end
end

# Main MagiCut group
main_group = project.main_group.children.find { |g| g.name == 'MagiCut' || g.path == 'MagiCut' }
unless main_group
  puts "MagiCut group not found!"
  exit 1
end

add_files_to_group(project, target, main_group, 'MagiCut')

project.save
puts "Successfully synced xcodeproj."
