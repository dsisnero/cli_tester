require "yaml"
require "random/secure"
require "log"
require "process"
require "file_utils"
require "./environment" # Need Environment for @env

module CliTester
  # Handles finding the shard.yml of the project being tested
  # and compiling its binaries within a test environment.
  class ShardBinary
    # Class properties to store the detected project root and shard file path.
    # Initialized by `configure`.
    class_property root_dir : String = Dir.current
    class_property shard_file : String = File.join(root_dir, "shard.yml")

    # Searches upwards from the current directory to find shard.yml.
    # Raises an error if not found.
    # @return [String] The absolute path to the found shard.yml.
    private def self.find_shard_yml : String
      current_dir = Dir.current
      loop do
        path = File.join(current_dir, "shard.yml")
        return path if File.exists?(path)

        parent_dir = File.dirname(current_dir)
        # Stop if we reached the root directory or cannot go further up
        break if parent_dir == current_dir || parent_dir == "/" && !File.exists?(File.join(parent_dir, "shard.yml"))
        current_dir = parent_dir
      end
      raise "shard.yml not found in directory hierarchy starting from #{Dir.current}"
    end

    # Finds the project's shard.yml and sets the class properties
    # `root_dir` and `shard_file` accordingly. This should be called
    # once when the CliTester module is loaded.
    def self.configure
      found_shard_file = find_shard_yml
      @@shard_file = found_shard_file
      @@root_dir = File.dirname(found_shard_file)
      Log.debug { "CliTester configured: root_dir=#{@@root_dir}, shard_file=#{@@shard_file}" }
    rescue ex
      Log.warn(exception: ex) { "CliTester configure failed to find shard.yml. shard_binary may not work." }
      # Keep default values if not found, allowing tests without shard_binary usage
    end

    # Initializes the compiler helper with a reference to the
    # test environment where the binary will be built.
    # @param env [Environment] The test environment instance.
    def initialize(@env : Environment)
    end

    # Compiles a target binary defined in the project's shard.yml.
    # The compiled binary is placed inside the test environment's `build` directory.
    #
    # @param name [String?] The specific target name from shard.yml to build.
    #                       If nil, attempts to build the first target or the shard name.
    # @param build_args [Array(String)] Additional arguments passed to `crystal build`.
    # @return [String] The absolute path to the compiled binary within the test environment.
    def compile(name : String? = nil, build_args : Array(String) = [] of String) : String
      original_dir = Dir.current
      begin
        # Change to the project's root directory to resolve relative paths in shard.yml
        Log.debug { "Changing directory to #{@@root_dir} for build" }
        Dir.cd(@@root_dir) do
          # Parse shard.yml from the configured path
          Log.debug { "Parsing shard file: #{@@shard_file}" }
          shard_yml = YAML.parse(File.read(@@shard_file))

          # Determine target name and main file
          target_name = name || begin
            targets_node = shard_yml["targets"]?
            if targets_node && targets_node.is_a?(YAML::Nodes::Mapping) && !targets_node.empty?
              first_key_node = targets_node.as_h.keys.first?
              if first_key_node.is_a?(YAML::Nodes::Scalar)
                first_key_node.value # Use the actual scalar value of the key
              else
                # Handle cases where the key might not be a simple string (though unlikely for target names)
                Log.warn { "First target key in shard.yml is not a simple string, falling back to shard name." }
                shard_yml["name"].as_s
              end
            else
              shard_yml["name"].as_s # Fallback to shard name if no targets section or it's empty
            end
          end
          Log.debug { "Determined target name: #{target_name}" }

          # Get target configuration and main file path
          main_file = begin
            targets_node = shard_yml["targets"]?
            target_config = nil

            if targets_node && targets_node.is_a?(YAML::Nodes::Mapping)
              target_config = targets_node[target_name]? # Access target config by name
            end

            main_path_node = if target_config && target_config.is_a?(YAML::Nodes::Mapping)
                               target_config["main"]?
                             else
                               nil
                             end

            if main_path_node && main_path_node.is_a?(YAML::Nodes::Scalar)
              main_path_node.value
            else
              # Default if 'main' not found or target_config is not a mapping
              default_main = "src/#{target_name}.cr"
              Log.debug { "Main file not specified for target '#{target_name}', defaulting to #{default_main}" }
              default_main
            end
          end
          Log.debug { "Determined main file: #{main_file}" }

          # Verify main file exists relative to the project root (@@root_dir)
          absolute_main_file = File.expand_path(main_file, @@root_dir)
          unless File.exists?(absolute_main_file)
            raise "Main file '#{main_file}' (resolved to '#{absolute_main_file}') not found for target '#{target_name}' in shard at '#{@@root_dir}'"
          end

          # Create build directory within the CliTester environment path
          build_dir = File.join(@env.path, "build")
          FileUtils.mkdir_p(build_dir) # Use FileUtils for safety
          binary_path = File.join(build_dir, target_name)

          # Add .exe extension for Windows
          {% if flag?(:win32) %}
            binary_path += ".exe"
          {% end %}
          Log.debug { "Target binary path: #{binary_path}" }

          # Build command - include the main source file (use absolute path for clarity)
          args = ["build", absolute_main_file, "-o", binary_path] + build_args
          Log.info { "Executing build command: crystal #{args.join(" ")}" }

          # Execute build (runs from @@root_dir due to Dir.cd block)
          status = Process.run(
            "crystal",
            args,
            output: Process::Redirect::Inherit, # Show build output directly
            error: Process::Redirect::Inherit
          )

          raise "Build failed with status #{status.exit_code} for command: crystal #{args.join(" ")}" unless status.success?

          Log.info { "Build successful: #{binary_path}" }
          binary_path # Return the path to the built binary
        end
      ensure
        # Ensure we change back to the original directory even if errors occur
        Log.debug { "Changing directory back to #{original_dir}" }
        Dir.cd(original_dir)
      end
    end
  end
end
