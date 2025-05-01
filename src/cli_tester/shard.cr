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
            # Loop while the next event is a scalar (a key)
            while parser.scalar?
              key = parser.read_scalar

              case key
              when "name"
                name = parser.read_scalar
              when "version"
                version = parser.read_scalar
              when "targets"
                parser.read_mapping do
                  # Loop while the next event is a scalar (a target name)
                  while parser.kind == YAML::Event::SCALAR
                    target_name = parser.read_scalar
                    main_path = nil

                    parser.read_mapping do
                      # Loop while the next event is a scalar (a key within the target, e.g., "main")
                      while parser.kind == YAML::Event::SCALAR
                        main_key = parser.read_scalar
                        if main_key == "main"
                          main_path = parser.read_scalar
                        else
                          parser.skip # Skip unknown keys within a target definition
                        end
                      end
                      # End of inner mapping (target definition)
                    end

                    raise "Missing 'main' for target #{target_name}" unless main_path
                    targets[target_name] = Target.new(main_path)
                  end
                  # End of targets mapping
                end
              else
                parser.skip # Skip unknown top-level keys
              end
            end
            # End of top-level mapping
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
