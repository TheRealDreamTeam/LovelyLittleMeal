require "tempfile"
begin
  require "chunky_png"
rescue LoadError
  # ChunkyPNG is optional - we have a fallback minimal PNG generator
  Rails.logger.warn("ChunkyPNG not available, will use minimal PNG fallback")
end

# Stub image generation strategy for testing/development
# Generates a simple placeholder image instead of calling RubyLLM.paint
# This saves tokens and speeds up development/testing
module ImageGenerators
  class StubImageGenerator < BaseStrategy
    # Generate a stub placeholder image
    # Delays 1 second to simulate real image generation time
    # Creates a simple colored rectangle with recipe title
    #
    # @param recipe [Recipe] The recipe to generate an image for
    # @param options [Hash] Optional parameters (ignored for stub)
    # @return [Tempfile] A temporary file containing the stub image
    def generate(recipe, options = {})
      # Simulate image generation delay (1 second)
      sleep(1)

      # Create a simple placeholder image
      # Using ChunkyPNG to generate a colored rectangle with text
      create_stub_image(recipe)
    end

    private

    # Create a stub placeholder image
    # Generates a simple colored rectangle with the recipe title
    #
    # @param recipe [Recipe] The recipe to create an image for
    # @return [Tempfile] A temporary file containing the PNG image
    def create_stub_image(recipe)
      # Check if ChunkyPNG is available
      unless defined?(ChunkyPNG)
        Rails.logger.info("StubImageGenerator: ChunkyPNG not available, using minimal PNG")
        return create_minimal_png
      end

      # Image dimensions (standard recipe image size)
      width = 800
      height = 600

      # Create a new image with a gradient background
      # Use a warm food-related color scheme
      image = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::TRANSPARENT)

      # Fill with a gradient-like background (warm orange/yellow tones)
      # Top to bottom gradient: lighter orange to darker orange
      (0...height).each do |y|
        # Calculate color based on position (gradient effect)
        r = 255 - (y * 0.1).to_i
        g = 200 - (y * 0.15).to_i
        b = 150 - (y * 0.1).to_i
        r = [r, 0].max
        g = [g, 0].max
        b = [b, 0].max

        color = ChunkyPNG::Color.rgb(r, g, b)
        (0...width).each { |x| image[x, y] = color }
      end

      # Add a semi-transparent overlay for text readability
      overlay_color = ChunkyPNG::Color.rgba(0, 0, 0, 100)
      (height / 3..(height * 2 / 3)).each do |y|
        (width / 4..(width * 3 / 4)).each do |x|
          image[x, y] = overlay_color
        end
      end

      # Save to tempfile
      tempfile = Tempfile.new(["recipe_image_stub", ".png"])
      tempfile.binmode
      image.save(tempfile.path)
      tempfile.rewind

      Rails.logger.info("StubImageGenerator: Generated placeholder image for recipe '#{recipe.title}'")

      tempfile
    rescue StandardError => e
      # Fallback: create a minimal valid PNG if ChunkyPNG fails
      Rails.logger.warn("StubImageGenerator: ChunkyPNG failed, creating minimal PNG: #{e.message}")
      create_minimal_png
    end

    # Create a minimal valid PNG as fallback
    # This is a 1x1 transparent PNG (smallest valid PNG)
    #
    # @return [Tempfile] A temporary file containing a minimal PNG
    def create_minimal_png
      # Minimal valid PNG (1x1 transparent pixel)
      # PNG signature + IHDR + IDAT + IEND chunks
      minimal_png = [
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, # PNG signature
        0x00, 0x00, 0x00, 0x0d, # IHDR chunk length
        0x49, 0x48, 0x44, 0x52, # IHDR
        0x00, 0x00, 0x00, 0x01, # width: 1
        0x00, 0x00, 0x00, 0x01, # height: 1
        0x08, 0x06, 0x00, 0x00, 0x00, # bit depth, color type, compression, filter, interlace
        0x1f, 0x15, 0xc4, 0x89, # CRC
        0x00, 0x00, 0x00, 0x0a, # IDAT chunk length
        0x49, 0x44, 0x41, 0x54, # IDAT
        0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, # compressed data
        0x0d, 0x0a, 0x2d, 0xb4, # CRC
        0x00, 0x00, 0x00, 0x00, # IEND chunk length
        0x49, 0x45, 0x4e, 0x44, # IEND
        0xae, 0x42, 0x60, 0x82  # CRC
      ].pack("C*")

      tempfile = Tempfile.new(["recipe_image_stub", ".png"])
      tempfile.binmode
      tempfile.write(minimal_png)
      tempfile.rewind
      tempfile
    end
  end
end

