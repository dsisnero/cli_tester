# cli_tester

Crystal testing utility for CLI applications. Provides isolated environments and tools to test command-line interactions.

## Features
- 💻 **Isolated Environments**: Automatic temp directory creation/cleanup
- 📂 **File System Helpers**: Create/read/remove files & directories
- ⚡ **Command Execution**: Run commands and capture stdout/stderr
- 🤖 **Interactive Testing**: Send input and wait for output patterns
- 🧹 **Automatic Cleanup**: Ensures test artifacts are removed

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

## Development
```bash
# Run tests
crystal spec

# Build documentation
crystal docs
```

## Contributing

1. Fork it (<https://github.com/dsisnero/cli_tester/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Dominic Sisneros](https://github.com/dsisnero) - creator and maintainer
