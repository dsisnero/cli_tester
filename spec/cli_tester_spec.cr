require "./spec_helper"

describe CliTester do
  it "provides a temporary environment via .test and cleans up" do
    temp_path = ""
    CliTester.test do |env|
      env.should be_a(CliTester::Environment)
      temp_path = env.path
      Dir.exists?(temp_path).should be_true
      env.write_file("test.txt", "hello")
      File.exists?(File.join(temp_path, "test.txt")).should be_true
    end

    # Check cleanup
    temp_path.should_not be_empty
    Dir.exists?(temp_path).should be_false
  end

  it "handles exceptions within the test block and still cleans up" do
    temp_path = ""
    expect_raises(Exception, "Test exception") do # Changed from RuntimeError
      CliTester.test do |env|
        temp_path = env.path
        Dir.exists?(temp_path).should be_true
        raise "Test exception"
      end
    end

    # Check cleanup even after exception
    temp_path.should_not be_empty
    Dir.exists?(temp_path).should be_false
  end
end
