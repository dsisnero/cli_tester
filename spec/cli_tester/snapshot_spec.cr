require "../spec_helper"
require "file_utils"

describe CliTester::Snapshot do
  test_snapshot = File.join(Dir.tempdir, "snapshot_test.txt")

  after_each do
    File.delete(test_snapshot) if File.exists?(test_snapshot)
  end

  it "creates new snapshots" do
    content = "test content"
    CliTester::Snapshot.assert_match_snapshot(content, test_snapshot)
    File.read(test_snapshot).should eq content
  end

  it "matches existing snapshots" do
    content = "consistent content"
    File.write(test_snapshot, content)
    CliTester::Snapshot.assert_match_snapshot(content, test_snapshot)
  end

  it "detects mismatches" do
    File.write(test_snapshot, "original")
    expect_raises(Exception, /Snapshot mismatch/) do
      CliTester::Snapshot.assert_match_snapshot("modified", test_snapshot)
    end
  end
end
