# cli_tester

Crystal testing utility for CLI applications. Provides isolated environments and tools to test command-line interactions.

## Features
- 🧹 **Output Normalization**
  - ANSI code stripping
  - Path placeholder replacement (`{base}`, `{home}`)
  - Non-printable character filtering
- 📸 **Snapshot Testing**
  - Golden master comparisons
  - Diff visualization
- 🤖 **Interactive Testing**
  - Input/response sequencing
  - Timeout handling
- ⚡ **Mock Adapters**
  - Dependency substitution
  - Scoped mock lifetimes

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
      # Setup test environment
      env.write_file("input.txt", "test data")
      env.make_dir("output")

      # Run and verify command
      result = env.execute("my_cli --input input.txt --output output/")
      result.success?.should be_true
      env.exists?("output/results.csv").should be_true

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
