require "../spec_helper"

# Mock adapter for testing the with_mocks functionality
class TestMock < CliTester::MockAdapter
  getter called = false

  def apply_mocks
    @called = true
  end
end

describe CliTester::Environment do
  # Tests basic directory creation and removal functionality
  describe "file system helpers" do
    it "creates nested directories and verifies existence" do
      CliTester.test do |env|
        env.make_dir("a/b/c")
        env.exists?("a").should be_true
        env.exists?("a/b").should be_true
        env.exists?("a/b/c").should be_true
        File.directory?(File.join(env.path, "a/b/c")).should be_true

        env.remove_dir("a")
        env.exists?("a").should be_false
      end
    end

    it "writes and reads files with write_file and read_file/read_file_bytes" do
      CliTester.test do |env|
        content_str = "Hello World\nLine 2"
        content_bytes = Bytes[72, 101, 108, 108, 111] # "Hello"

        env.write_file("test.txt", content_str)
        env.exists?("test.txt").should be_true
        env.read_file("test.txt").should eq content_str

        env.write_file("test.bin", content_bytes)
        env.exists?("test.bin").should be_true
        env.read_file_bytes("test.bin").should eq content_bytes
      end
    end

    it "overwrites files with write_file" do
      CliTester.test do |env|
        env.write_file("overwrite.txt", "first")
        env.read_file("overwrite.txt").should eq "first"
        env.write_file("overwrite.txt", "second")
        env.read_file("overwrite.txt").should eq "second"
      end
    end

    it "removes files with remove_file and leaves other files untouched" do
      CliTester.test do |env|
        # Setup: Create two files
        env.write_file("to_remove.txt", "content")
        env.write_file("keep.txt", "important")

        # Pre-conditions
        env.exists?("to_remove.txt").should be_true
        env.exists?("keep.txt").should be_true
        env.exists?("non_existent.txt").should be_false

        # Action: Remove one file and attempt to remove non-existent
        env.remove_file("to_remove.txt")
        env.remove_file("non_existent.txt")

        # Verify post-conditions
        env.exists?("to_remove.txt").should be_false
        env.exists?("keep.txt").should be_true # Ensure other file remains
        env.exists?("non_existent.txt").should be_false
      end
    end

    it "lists directory contents with ls" do
      CliTester.test do |env|
        env.make_dir("dir1")
        env.write_file("file1.txt", "")
        env.write_file("dir1/file2.txt", "")

        entries = env.ls(".")
        entries.sort.should contain("dir1")
        entries.sort.should contain("file1.txt")
        entries.sort.should contain("xdg")  # Add this line

        entries_subdir = env.ls("dir1")
        entries_subdir.should eq ["file2.txt"]
      end
    end

    it "checks existence with exists?" do
      CliTester.test do |env|
        env.exists?("anything").should be_false
        env.make_dir("a_dir")
        env.exists?("a_dir").should be_true
        env.write_file("a_file", "")
        env.exists?("a_file").should be_true
      end
    end

    it "handles paths correctly within chdir block" do
      # This test ensures file operations work correctly when Dir.cd is active
      CliTester.test do |env|
        # Operations inside the block should use relative paths correctly
        env.write_file("relative_file.txt", "inside")
        File.exists?("relative_file.txt").should be_true
        File.read("relative_file.txt").should eq "inside"

        env.make_dir("relative_dir")
        Dir.exists?("relative_dir").should be_true

        # Check resolution still works
        env.exists?("relative_file.txt").should be_true
        env.read_file("relative_file.txt").should eq "inside"
      end
    end
  end

  # Tests command execution with various input types
  describe "#execute" do
    it "executes a simple command and captures output" do
      CliTester.test do |env|
        result = env.execute("echo 'Hello Tester'")
        result.success?.should be_true
        result.exit_code.should eq 0
        result.stdout.should eq "Hello Tester\n"
        result.stderr.should be_empty
      end
    end

    it "captures stderr" do
      CliTester.test do |env|
        # Use sh to redirect echo to stderr
        result = env.execute("sh -c \"echo 'Error Message' >&2\"")
        result.success?.should be_true
        result.exit_code.should eq 0
        result.stdout.should be_empty
        result.stderr.should eq "Error Message\n"
      end
    end

    it "captures non-zero exit codes" do
      CliTester.test do |env|
        result = env.execute("sh -c 'exit 5'")
        result.success?.should be_false
        result.exit_code.should eq 5
        result.stdout.should be_empty
        result.stderr.should be_empty
      end
    end

    it "passes input string to the command" do
      CliTester.test do |env|
        result = env.execute("cat", input: "Input Data")
        result.success?.should be_true
        result.stdout.should eq "Input Data"
      end
    end

    it "handles binary input through pipes" do
      # Tests binary data handling
      CliTester.test do |env|
        input_bytes = Bytes[1, 2, 3, 4]
        # Use od to verify binary input (output format depends on od version/flags)
        # This checks if the input is passed, not the exact od output format
        result = env.execute("od -t x1", input: input_bytes)
        result.success?.should be_true
        result.stdout.should contain("01 02 03 04") # Check if the bytes appear in hex output
      end
    end

    it "sets environment variables for the command" do
      CliTester.test do |env|
        result = env.execute("sh -c 'echo $TEST_VAR'", env: {"TEST_VAR" => "TestValue123"})
        result.success?.should be_true
        result.stdout.should eq "TestValue123\n"
      end
    end

    it "runs the command within the temporary directory" do
      CliTester.test do |env|
        env.write_file("marker.txt", "present")
        # Use ls within sh to avoid potential alias issues
        result = env.execute("sh -c 'ls'")
        result.success?.should be_true
        result.stdout.should contain("marker.txt")

        # Verify pwd output matches the temp dir path
        result_pwd = env.execute("pwd")
        result_pwd.success?.should be_true
        result_pwd.stdout.strip.should eq env.path
      end
    end
  end

  describe "#with_mocks" do
    it "applies mocks during execution" do
      CliTester.test do |env|
        mock = TestMock.new

        env.with_mocks(mock) do
          # Test that mock was applied
          mock.called.should be_true

          # Example command that would use mocks
          result = env.execute("echo 'mock test'")
          result.stdout.should contain("mock test")
        end
      end
    end
  end

  describe "output normalization" do
    it "normalizes stdout and stderr" do
      CliTester.test do |env|
        env.write_file("test.txt", "content")

        # Command that outputs paths and colors
        # Use printf via sh for better escape code handling than echo -e
        result = env.execute("sh -c 'printf \"\\033[32m#{env.path}/test.txt\\033[0m\\n\"'")

        # Raw output should contain actual path and color codes
        result.stdout.should contain(env.path)
        result.stdout.should contain("\e[32m")

        # Normalized output should have placeholders and no colors
        normalized = result.normalized_stdout(env)
        normalized.should eq "{base}/test.txt\n"
      end
    end
  end

  describe "#setup_xdg_environment" do
    it "creates standard XDG directories in temp environment" do
      CliTester.test do |env|
        base = File.join(env.path, "xdg")
        ["config", "cache", "data", "state"].each do |dir|
          path = File.join(base, dir)
          Dir.exists?(path).should be_true
          env.env["XDG_#{dir.upcase}_HOME"].should eq(path)
        end
      end
    end
  end

  describe "#create_xdg_config" do
    it "writes files to app-specific config directory" do
      CliTester.test do |env|
        env.create_xdg_config("testapp", "config.yml", "key: value")

        config_path = File.join(
          env.env["XDG_CONFIG_HOME"],
          "testapp",
          "config.yml"
        )

        File.read(config_path).should eq("key: value")
        File.exists?(config_path).should be_true
      end
    end
  end

  describe "#with_temp_env" do
    it "sets and resets environment variables" do
      original_value = ENV["SPEC_TEST_VAR"]?

      CliTester.test do |env|
        env.with_temp_env({"SPEC_TEST_VAR" => "temp"}) do
          ENV["SPEC_TEST_VAR"]?.should eq("temp")
        end

        ENV["SPEC_TEST_VAR"]?.should eq(original_value)
      end
    ensure
      ENV.delete("SPEC_TEST_VAR")
      ENV["SPEC_TEST_VAR"] = original_value if original_value
    end

    it "unsets variables when value is nil" do
      ENV["TO_BE_UNSET"] = "exists"

      CliTester.test do |env|
        env.with_temp_env({"TO_BE_UNSET" => nil}) do
          ENV["TO_BE_UNSET"]?.should be_nil
        end
      end
    ensure
      ENV.delete("TO_BE_UNSET")
    end
  end
end
