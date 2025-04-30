require "yaml" # Need this for YAML::PullParser and YAML::ParseException

module CliTester
  # Represents a parsed shard.yml configuration with validation
  class Shard
    getter name : String
    getter version : String?
    getter targets : Hash(String, Target)

    struct Target
      getter main : String

      def initialize(@main : String)
      end
    end

    def initialize(@name : String, @version : String? = nil, @targets = {} of String => Target)
    end

    # Parses shard.yml content using YAML::PullParser for safety
    def self.parse(content : String) : Shard
      parser = YAML::PullParser.new(content)
      name = nil
      version = nil
      targets = {} of String => Target

      parser.read_stream do
        parser.read_document do
          parser.read_mapping do
            key = parser.read_scalar? # Use read_scalar? for potentially empty mappings
            until key.nil?
              case key
              when "name"
                name = parser.read_scalar
              when "version"
                version = parser.read_scalar
              when "targets"
                parser.read_mapping do
                  target_name = parser.read_scalar? # Use read_scalar? for potentially empty mappings
                  until target_name.nil?
                    main_path = nil
                    parser.read_mapping do
                      main_key = parser.read_scalar? # Use read_scalar? for potentially empty mappings
                      until main_key.nil?
                        if main_key == "main"
                          main_path = parser.read_scalar
                        else
                          parser.skip # Skip unknown keys within a target definition
                        end
                        main_key = parser.read_scalar?
                      end
                    end
                    raise "Missing 'main' for target #{target_name}" unless main_path
                    targets[target_name] = Target.new(main_path)
                    target_name = parser.read_scalar?
                  end
                end
              else
                parser.skip # Skip unknown top-level keys
              end
              key = parser.read_scalar?
            end
          end
        end
      end

      raise "Missing required 'name' field in shard.yml" unless name
      Shard.new(name, version, targets)
    rescue ex : YAML::ParseException
      raise "Invalid shard.yml: #{ex.message}"
    end
  end
end
