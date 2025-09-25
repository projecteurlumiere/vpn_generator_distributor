require "zeitwerk"

loader = Zeitwerk::Loader.new
root_path = File.expand_path("..", __dir__)
loader.push_dir(File.join(root_path, "models"))
loader.push_dir(File.join(root_path, "controllers"))
loader.collapse(File.join(root_path, "controllers", "modules"))
loader.push_dir(File.join(root_path, "lib"))
loader.setup
