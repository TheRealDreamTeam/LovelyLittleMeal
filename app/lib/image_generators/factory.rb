# Factory for creating image generator strategies
# Determines which strategy to use based on configuration
#
# Configuration options:
# - ENV['IMAGE_GENERATION_STRATEGY']: 'real' or 'stub' (default: 'stub' in development, 'real' in production)
# - Rails.env: Automatically uses 'stub' in development/test, 'real' in production
module ImageGenerators
  class Factory
    # Get the appropriate image generator strategy
    # Checks ENV variable first, then falls back to environment-based defaults
    #
    # @return [BaseStrategy] The image generator strategy to use
    def self.create
      strategy_name = ENV.fetch("IMAGE_GENERATION_STRATEGY", default_strategy)

      case strategy_name.downcase
      when "real", "production"
        RealImageGenerator.new
      when "stub", "test", "development"
        StubImageGenerator.new
      else
        Rails.logger.warn("Unknown IMAGE_GENERATION_STRATEGY: #{strategy_name}, defaulting to stub")
        StubImageGenerator.new
      end
    end

    # Determine default strategy based on Rails environment
    #
    # @return [String] The default strategy name
    def self.default_strategy
      if Rails.env.production?
        "real"
      else
        # Development and test default to stub to save tokens
        "stub"
      end
    end
  end
end
