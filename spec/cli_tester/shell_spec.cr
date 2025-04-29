require "../spec_helper"

describe CliTester::Shell do
  it "escapes POSIX commands" do
    {% if !flag?(:win32) %}
      # Before: .should eq "echo 'test'"
      CliTester::Shell.escape("echo 'test'").should eq "'echo '\\''test'\\'''"
      CliTester::Shell.escape("file with spaces").should eq "'file with spaces'"
    {% end %}
  end

  it "escapes Windows commands" do
    {% if flag?(:win32) %}
      CliTester::Shell.escape("dir \"My Documents\"").should eq "dir \"\"My Documents\"\""
    {% end %}
  end

  describe "#xdg_command" do
    {% if flag?(:win32) %}
      it "formats Windows command with set" do
        command = CliTester::Shell.xdg_command("myapp --version", "C:\\test config")
        command.should eq("set XDG_CONFIG_HOME=\"C:\\test config\" && myapp --version")
      end
    {% else %}
      it "formats POSIX command with ENV prefix" do
        command = CliTester::Shell.xdg_command("myapp --version", "/test/config")
        command.should eq("XDG_CONFIG_HOME='/test/config' myapp --version")
      end

      it "escapes spaces in POSIX path" do
        command = CliTester::Shell.xdg_command("ls", "/path/with spaces")
        command.should contain("'/path/with spaces'")
      end
    {% end %}
  end
end
