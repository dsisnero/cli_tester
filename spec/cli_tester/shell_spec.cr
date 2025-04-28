require "../spec_helper"

describe CliTester::Shell do
  it "escapes POSIX commands" do
    {% if !flag?(:win32) %}
      CliTester::Shell.escape("echo 'test'").should eq "echo 'test'"
      CliTester::Shell.escape("file with spaces").should eq "file\\ with\\ spaces"
    {% end %}
  end

  it "escapes Windows commands" do
    {% if flag?(:win32) %}
      CliTester::Shell.escape("dir \"My Documents\"").should eq "dir \"\"My Documents\"\""
    {% end %}
  end
end
