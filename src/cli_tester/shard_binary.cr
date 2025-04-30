require "spec"
require "yaml"

module CliTester
  # Helper method to get the compiled binary from shard.yml
  def shard_binary(*, temp_path = "tmp", args = [] of String)
    # Parse shard.yml to find the targets
    shard_yml = YAML.parse(File.read("shard.yml"))

    # Get the first target or use the default name from shard name
    target_name = if shard_yml["targets"]?
                    shard_yml["targets"].as_h.keys.first.to_s
                  else
                    shard_yml["name"].to_s
                  end

    # Create the binary path
    binary_path = File.join(temp_path, target_name)

    # Ensure the directory exists
    Dir.mkdir_p(temp_path)

    # Build the binary
    build_args = ["build", "-o", binary_path] + args
    status = Process.run("crystal", build_args)

    # Check if build was successful
    unless status.success?
      raise "Failed to compile shard binary"
    end

    # Return the path to the binary
    binary_path
  end
end
