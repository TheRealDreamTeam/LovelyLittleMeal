# Base strategy interface for image generation
# All image generator strategies must implement the generate method
#
# This allows switching between real image generation (RubyLLM.paint) and
# stub implementations for testing/development without wasting tokens
module ImageGenerators
  class BaseStrategy
    # Generate an image based on the recipe data
    #
    # @param recipe [Recipe] The recipe to generate an image for
    # @param options [Hash] Optional parameters (model, size, etc.)
    # @return [Tempfile] A temporary file containing the generated image
    # @raise [StandardError] If image generation fails
    def generate(recipe, options = {})
      raise NotImplementedError, "Subclasses must implement #generate"
    end

    # Build a descriptive prompt from recipe data
    # This is shared logic that all strategies can use
    #
    # @param recipe [Recipe] The recipe to build a prompt for
    # @return [String] The image generation prompt
    def build_image_prompt(recipe)
      # Extract key information from recipe
      title = recipe.title.presence || "a delicious recipe"
      description = recipe.description.presence || ""
      ingredients = recipe.content&.dig("ingredients") || []

      # Build a rich prompt for food photography
      # Include title, description, and key ingredients for accuracy
      # CRITICAL: Never add any text on the image - this ensures clean food photography
      prompt_parts = [
        "Professional food photography of",
        title,
        description.present? ? ", #{description.downcase}" : "",
        ingredients.any? ? ". Featuring #{ingredients.first(3).join(', ')}" : "",
        ". High quality, appetizing, well-lit, restaurant style food photography",
        ". CRITICAL: Do not add any text, labels, or words on the image - only the food itself"
      ]

      prompt_parts.join(" ").strip
    end
  end
end

