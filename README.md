# cli_tester

Crystal testing utility for CLI applications. Provides isolated environments and tools to test command-line interactions.

## Features
- **🔍 Shard Validation**
  - Automatic shard.yml detection
  - Configuration parsing with YAML validation
  - Required field checking (name, targets)
  - Precise error locations in YAML files
- **🖥️ XDG Compliance Testing**
- **🔀 Environment Isolation**
- **🧹 Output Normalization**
- **📸 Snapshot Testing**
- **🤖 Interactive Testing**
- **⚡ Mock Adapters**

## Installation

Add to `shard.yml`:
```yaml
dependencies:
  cli_tester:
    github: dsisnero/cli_tester
```

Then run:
```bash
shards install
```

## Usage

```crystal
require "cli_tester"

describe "MyCLI" do
  it "tests CLI behavior" do
    CliTester.test do |env|
      # XDG Config Testing
      env.create_xdg_config("myapp", "config.yml", "debug: true")

      # Temporary ENV variables
      env.with_temp_env({"APP_MODE" => "test"}) do
        # XDG-aware command execution
        # Ensure XDG_CONFIG_HOME is set for the command
        config_home = env.env["XDG_CONFIG_HOME"]
        cmd = CliTester::Shell.xdg_command("myapp --verbose", config_home)
        result = env.execute(cmd)

        result.stdout.should contain("Debug mode enabled")
        # Example: Check cache file created by the app
        # env.read_file("#{env.env["XDG_CACHE_HOME"]}/myapp/cache.dat").should eq("cached")
      end

      # Test interactive prompts
      process = env.spawn("my_cli --interactive")
      process.wait_for_text("Enter name:")
      process.write_text("Tester")
      process.wait_for_finish
      process.stdout.should contain("Hello Tester")
    end
  end
end
```

## Shard Validation

Test your shard.yml configuration:

```crystal
it "validates shard configuration" do
  # Get parsed shard configuration
  shard = CliTester::Shard.parse(File.read(CliTester.shard_file))
  
  shard.name.should eq "my_cli"
  shard.targets["main"].main.should eq "src/main.cr"
  
  # Test invalid configurations
  invalid_yaml = <<-YAML
    version: 1.0
    targets:
      broken: {}
  YAML
  
  expect_raises(YAML::ParseException, /Missing required 'name' field/) do
    CliTester::Shard.parse(invalid_yaml)
  end
end
```

## XDG Environment Testing

Test XDG-compliant applications without touching real configs:

```crystal
it "uses XDG config locations" do
  CliTester.test do |env|
    # Create test config
    env.create_xdg_config("myapp", "settings.toml", <<-TOML
      [features]
      experimental = true
    TOML
    )

    # Verify config location
    config_path = File.join(env.env["XDG_CONFIG_HOME"], "myapp/settings.toml")
    File.exists?(config_path).should be_true

    # Test CLI behavior using XDG-aware command
    cmd = CliTester::Shell.xdg_command("myapp show-config", env.env["XDG_CONFIG_HOME"])
    result = env.execute(cmd)
    result.stdout.should contain("experimental: true")
  end
end
```

## Environment Variable Management

Safely test environment-dependent behavior:

```crystal
it "respects APP_DEBUG flag" do
  CliTester.test do |env|
    env.with_temp_env({
      "APP_DEBUG" => "1",
      "OLD_VAR"   => nil  # Unset during test
    }) do
      result = env.execute("myapp")
      result.stdout.should contain("[DEBUG]")
    end
  end
end
```

## Output Normalization Examples

```crystal
# Raw output contains color codes and paths:
"Processing \e[32m/tmp/cli-test-xyz/file.txt\e[0m"

# Normalized output becomes:
"Processing {base}/file.txt"
```

## Snapshot Testing

Update snapshots by:
1. Delete the snapshot file
2. Re-run tests - new snapshot will be generated

```crystal
CliTester::Snapshot.assert_match_snapshot(
  result.normalized_stdout(env),
  "spec/snapshots/main_output.txt"
)
```

## Mock Adapters

Example mocking HTTP calls:
```crystal
class MockSuccessAPI < CliTester::MockAdapter
  def apply_mocks
    MyHTTPClient.stub(:get, "https://api.example.com") do
      HTTP::Client::Response.new(200, "{\"status\":\"ok\"}")
    end
  end
end

env.with_mocks(MockSuccessAPI.new) do
  result = env.execute("my-cli fetch-data")
  # Assert against mocked response
end
```

## Interactive Testing Flow

```crystal
process = env.spawn("my-cli setup")
process.wait_for_text("Enter API key:")
process.write_text("test-key-123")
process.wait_for_text("Validating...", stream: :stderr)
process.wait_for_finish
process.get_stdout.should contain("Setup complete")
```

## Development Notes

```bash
# Run tests with output normalization:
CRYSTAL_LOG_LEVEL=DEBUG crystal spec

# Generate test coverage:
crystal spec --error-trace --debug -Dpreview_mt
```

## Roadmap
- [ ] Automated snapshot updates via env var
- [ ] Windows path normalization
- [ ] ANSI progress bar handling
- [ ] Multi-process concurrency testing

## Contributing

1. Fork it (<https://github.com/dsisnero/cli_tester/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Dominic Sisneros](https://github.com/dsisnero) - creator and maintainer
