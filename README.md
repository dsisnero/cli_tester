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

## Output Normalization

When comparing CLI output, especially across different runs or environments, variations like temporary paths, ANSI color codes, or minor character differences can cause test failures. `cli_tester` provides normalization helpers to create consistent output for assertions and snapshot testing.

The `ExecutionResult` object returned by `env.execute` has methods to access normalized output:

```crystal
CliTester.test do |env|
  # Example command that might produce color codes and temp paths
  result = env.execute("my-cli --color=always --output-dir #{env.path}/results")

  # Get normalized stdout
  norm_stdout = result.normalized_stdout(env)

  # Get normalized stderr
  norm_stderr = result.normalized_stderr(env)

  # Assertions on normalized output
  norm_stdout.should contain("Processing complete in {base}/results")
  norm_stdout.should_not contain("\e[32m") # Color codes removed
end
```

The library automatically performs the following normalizations via `OutputNormalizer.normalize`:
- Removes ANSI color codes (e.g., `\e[31m`).
- Replaces the temporary test directory path with the placeholder `{base}`.
- Replaces the user's home directory path with the placeholder `{home}`.
- Filters most non-printable characters (preserving common whitespace like newline and tab).

## Snapshot Testing

Snapshot testing is useful for verifying large or complex CLI outputs. Instead of writing exact string assertions in your test, you compare the command's output against a reference file (the "snapshot").

`cli_tester` provides a basic helper for this:

```crystal
require "cli_tester/snapshot" # Make sure to require the module

describe "MyCLI Report" do
  it "generates the correct report output" do
    CliTester.test do |env|
      result = env.execute("my-cli generate-report --format=json")

      # Compare normalized stdout against a snapshot file
      CliTester::Snapshot.assert_match_snapshot(
        result.normalized_stdout(env), # Use normalized output!
        "spec/snapshots/report_output.json"
      )
    end
  end
end
```

**How it works:**
1.  The first time the test runs, if `spec/snapshots/report_output.json` doesn't exist, it will be created with the current output of the command. The test will pass, and you should commit this snapshot file.
2.  On subsequent runs, the command's output is compared to the content of the existing snapshot file.
3.  If the output matches the snapshot, the test passes.
4.  If the output differs, the test fails, and a diff showing the differences is printed to the console.

**Updating Snapshots:**
*Currently, there is no automatic update flag.* If the output has legitimately changed and you need to update the snapshot, you must manually delete the snapshot file (`spec/snapshots/report_output.json` in the example) and re-run the test. The new output will then be saved as the updated snapshot.

## Mocking External Interactions

Testing CLIs that interact with external systems (APIs, databases, etc.) can be slow and unreliable. `cli_tester` provides a basic structure for applying mocks during tests.

1.  **Define a Mock Adapter:** Create a class inheriting from `CliTester::MockAdapter` and implement the `apply_mocks` method. This method should contain the logic to set up your mocks (e.g., stubbing HTTP client methods, replacing dependency instances).

    ```crystal
    require "cli_tester/mock_adapter"
    require "my_app/http_client" # Assuming your app has this

    class MockApiSuccess < CliTester::MockAdapter
      def apply_mocks
        # Example: Stubbing a class method using Crystal's built-in stubbing
        MyHttpClient.stub(:get).with("https://api.example.com/data").returns(
          HTTP::Client::Response.new(status_code: 200, body: %({"status": "ok", "value": 123}))
        )

        # Example: Stubbing an instance method (if needed)
        # instance = MyDependency.instance
        # instance.stub(:perform_action).returns(:mock_result)
      end
    end
    ```

2.  **Use `env.with_mocks`:** Wrap the code that should run with mocks inside the `env.with_mocks` block in your test.

    ```crystal
    CliTester.test do |env|
      # Apply the mocks defined in MockApiSuccess
      env.with_mocks(MockApiSuccess.new) do
        # This command will now use the mocked HTTP response
        result = env.execute("my-cli fetch-data --url https://api.example.com/data")

        result.success?.should be_true
        result.normalized_stdout(env).should contain("Successfully fetched data: Value=123")
      end

      # Outside the block, the mocks are no longer active (if stubbing was scope-limited)
    end
    ```

This approach allows you to isolate your CLI's logic from external dependencies during testing. You'll need to adapt the `apply_mocks` implementation based on how your application manages dependencies and how you prefer to perform mocking/stubbing in Crystal (e.g., using built-in `stub`, dependency injection, etc.).

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
