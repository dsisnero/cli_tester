require "../spec_helper"

describe CliTester::OutputNormalizer do
  it "strips ANSI color codes" do
    input = "\e[32mHello\e[0m \e[31mWorld\e[0m"
    CliTester::OutputNormalizer.strip_ansi_codes(input).should eq "Hello World"
  end

  it "normalizes paths" do
    base_path = "/tmp/cli_test_123"
    input = "Output in #{base_path}/subdir and #{Path.home}/config"
    expected = "Output in {base}/subdir and {home}/config"
    CliTester::OutputNormalizer.normalize_paths(input, base_path).should eq expected
  end

  it "filters non-printable characters" do
    input = "Hello\u0001World\t\n"
    CliTester::OutputNormalizer.clean_special_chars(input).should eq "HelloWorld\t\n"
  end

  it "full normalization flow" do
    base_path = "/tmp/cli_test_123"
    input = "\e[32mOutput in #{base_path}/subdir \u0001and #{Path.home}/config\e[0m\n"
    expected = "Output in {base}/subdir and {home}/config\n"

    normalized = CliTester::OutputNormalizer.normalize(input, base_path)
    normalized.should eq expected
  end
end
