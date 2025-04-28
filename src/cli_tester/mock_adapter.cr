module CliTester
  # Abstract base class for defining mocks to be applied within a test environment.
  # Subclasses should implement the `apply_mocks` method to set up specific
  # mock behaviors (e.g., stubbing HTTP requests, replacing dependencies).
  #
  # Example Usage:
  # ```
  # class MyApiMock < CliTester::MockAdapter
  #   def apply_mocks
  #     # Configure HTTP client, stub methods, etc.
  #     MyHttpClient.stub(:get).with("http://example.com/data").returns("mock data")
  #   end
  # end
  #
  # CliTester.test do |env|
  #   env.with_mocks(MyApiMock.new) do
  #     # Code inside this block runs with mocks applied
  #     result = env.execute("my-cli fetch --url http://example.com/data")
  #     result.stdout.should contain("mock data")
  #   end
  # end
  # ```
  abstract class MockAdapter
    # This method should be implemented by subclasses to define and activate
    # the specific mocks needed for a test scenario.
    abstract def apply_mocks

    # Optional: Add a teardown method if mocks need explicit cleanup,
    # though often relying on block scope or test framework teardown is sufficient.
    # def teardown_mocks
    # end
  end
end
