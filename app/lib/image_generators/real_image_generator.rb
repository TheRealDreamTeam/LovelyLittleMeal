require "net/http"
require "tempfile"
require "base64"
require "uri"
require "open-uri"

# Real image generation strategy using RubyLLM.paint
# This generates actual images using DALL-E 3 or other image generation models
module ImageGenerators
  class RealImageGenerator < BaseStrategy
    # Generate an image using RubyLLM.paint
    #
    # @param recipe [Recipe] The recipe to generate an image for
    # @param options [Hash] Optional parameters (model, size, etc.)
    # @return [Tempfile] A temporary file containing the generated image
    # @raise [StandardError] If image generation fails
    def generate(recipe, options = {})
      # Build a descriptive prompt from the recipe data
      prompt = build_image_prompt(recipe)

      # Generate image using RubyLLM.paint
      # RubyLLM.paint supports DALL-E 3 and other image generation models
      # It returns a URL or base64 encoded image data
      image_result = RubyLLM.paint(
        prompt,
        model: options.fetch(:model, "dall-e-3")
      )

      # Handle the response - RubyLLM.paint may return URL or base64 data
      image_data = extract_image_data(image_result)
      raise StandardError, "Failed to extract image data from RubyLLM.paint response" unless image_data

      # Download the image if it's a URL, or decode if it's base64
      image_file = download_or_decode_image(image_data)
      raise StandardError, "Failed to download or decode image" unless image_file

      image_file
    end

    private

    # Extract image data from RubyLLM.paint response
    # RubyLLM.paint returns a RubyLLM::Image object with url or data methods
    #
    # @param result [RubyLLM::Image, Hash, String] The result from RubyLLM.paint
    # @return [String, nil] The image URL or base64 data, or nil if not found
    def extract_image_data(result)
      # Handle RubyLLM::Image object (most common case)
      if result.respond_to?(:url)
        # RubyLLM::Image object - get the URL
        url = result.url
        return url if url.present?
      end

      if result.respond_to?(:data)
        # RubyLLM::Image object with data method
        data = result.data
        return data if data.present?
      end

      # Handle other formats
      case result
      when String
        # Direct URL or base64 string
        result
      when Hash
        # Structured response - check common keys
        result["url"] || result[:url] || result["data"] || result[:data] || result.dig("data", 0,
                                                                                     "url") || result.dig("data", 0,
                                                                                                          "b64_json")
      when Array
        # Array of results - take first
        return nil if result.empty?

        extract_image_data(result.first)
      else
        Rails.logger.warn("Unexpected image generation result format: #{result.class}")
        nil
      end
    end

    # Download image from URL or decode base64 data
    # Returns a Tempfile with the image data
    #
    # @param image_data [String] URL or base64 encoded image data
    # @return [Tempfile, nil] The image file or nil on failure
    def download_or_decode_image(image_data)
      # Handle base64 encoded images
      # Check for data URI format or pure base64 string
      if image_data.start_with?("data:image") || (image_data.length > 100 && image_data.match?(%r{\A[A-Za-z0-9+/]+={0,2}\z}))
        # Base64 encoded image
        base64_data = image_data.start_with?("data:image") ? image_data.split(",")[1] : image_data
        image_binary = Base64.decode64(base64_data)

        tempfile = Tempfile.new(["recipe_image", ".png"])
        tempfile.binmode
        tempfile.write(image_binary)
        tempfile.rewind
        tempfile
      else
        # URL-based image - try using open-uri first (simpler, handles redirects)
        # Fall back to Net::HTTP if open-uri fails
        begin
          downloaded_file = URI.open(image_data, "User-Agent" => "Ruby/Rails", "Accept" => "image/*", read_timeout: 30)
          tempfile = Tempfile.new(["recipe_image", ".png"])
          tempfile.binmode
          tempfile.write(downloaded_file.read)
          tempfile.rewind
          downloaded_file.close
          tempfile
        rescue StandardError => e
          Rails.logger.warn("open-uri failed, trying Net::HTTP: #{e.message}")

          # Fallback to Net::HTTP
          uri = URI.parse(image_data)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == "https")
          http.read_timeout = 30

          # Build request with full URI (including query parameters if present)
          request_path = uri.path
          request_path += "?#{uri.query}" if uri.query
          request = Net::HTTP::Get.new(request_path)

          # Add headers that might be required
          request["User-Agent"] = "Ruby/Rails"
          request["Accept"] = "image/*"

          response = http.request(request)

          unless response.is_a?(Net::HTTPSuccess)
            Rails.logger.error("Failed to download image: HTTP #{response.code} - #{response.message}")
            Rails.logger.error("URL: #{image_data}")
            Rails.logger.error("Response body: #{response.body[0..500]}") if response.body
            raise StandardError, "Failed to download image: HTTP #{response.code} - #{response.message}"
          end

          tempfile = Tempfile.new(["recipe_image", ".png"])
          tempfile.binmode
          tempfile.write(response.body)
          tempfile.rewind
          tempfile
        end
      end
    rescue StandardError => e
      Rails.logger.error("Failed to process image data: #{e.message}")
      nil
    end
  end
end

