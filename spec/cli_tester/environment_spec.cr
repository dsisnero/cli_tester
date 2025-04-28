require "../spec_helper"

describe CliTester::Environment do
  describe "file system helpers" do
    it "creates and manages directories with make_dir and remove_dir" do
      CliTester.test do |env|
        env.make_dir("a/b/c")
        env.exists?("a").should be_true
        env.exists?("a/b").should be_true
        env.exists?("a/b/c").should be_true
        Dir.info(File.join(env.path, "a/b/c")).type.should eq File::Type::Directory

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

    it "removes files with remove_file" do
      CliTester.test do |env|
        env.write_file("to_remove.txt", "content")
        env.exists?("to_remove.txt").should be_true
        env.remove_file("to_remove.txt")
        env.exists?("to_remove.txt").should be_false
        # Removing non-existent file should not raise
        expect_not_raises { env.remove_file("non_existent.txt") }
      end
    end

    it "lists directory contents with ls" do
      CliTester.test do |env|
        env.make_dir("dir1")
        env.write_file("file1.txt", "")
        env.write_file("dir1/file2.txt", "")

        entries = env.ls(".")
        entries.sort.should eq ["dir1", "file1.txt"]

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

    it "passes input bytes to the command" do
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
end
