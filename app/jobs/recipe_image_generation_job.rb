# Background job for generating recipe images asynchronously
# Uses the ImageGenerators strategy pattern to support both real and stub image generation
# This allows image generation to happen in parallel without blocking the main request
# Multiple jobs can run concurrently, enabling parallelization of image generation
#
# The job generates an image based on the final recipe data (title, description, ingredients)
# to ensure the image accurately represents the recipe after all validations and adjustments
#
# Strategy selection:
# - Set ENV['IMAGE_GENERATION_STRATEGY'] to 'real' or 'stub'
# - Defaults to 'stub' in development/test, 'real' in production
class RecipeImageGenerationJob < ApplicationJob
  # Queue name for organizing jobs (optional, defaults to 'default')
  queue_as :default

  # Retry configuration: retry up to 3 times with polynomial backoff
  # Image generation failures are retried since they're non-critical but improve UX
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Discard job if recipe no longer exists (user deleted it)
  discard_on ActiveRecord::RecordNotFound

  # Perform the image generation job
  # This method is called by ActiveJob when the job is executed
  #
  # @param recipe_id [Integer] The ID of the recipe to generate an image for
  # @param options [Hash] Optional parameters for image generation (size, quality, style, model, force_regenerate)
  def perform(recipe_id, options = {})
    recipe = Recipe.find(recipe_id)

    # Skip if image already exists and regeneration is not forced
    # This prevents regenerating images unnecessarily for minor changes
    # force_regenerate: true allows regeneration even if image exists (for significant recipe changes)
    return if recipe.image.attached? && !options.fetch(:force_regenerate, false)

    # If forcing regeneration, purge the old image first
    # This ensures we don't accumulate old images and the new image replaces the old one
    recipe.image.purge if options.fetch(:force_regenerate, false) && recipe.image.attached?

    # Get the appropriate image generator strategy
    # Uses factory to determine which strategy to use (real or stub)
    # Strategy is determined by ENV['IMAGE_GENERATION_STRATEGY'] or environment defaults
    image_generator = ImageGenerators::Factory.create

    # Generate image using the selected strategy
    # RealImageGenerator uses RubyLLM.paint, StubImageGenerator creates a placeholder
    image_file = image_generator.generate(recipe, options)
    return unless image_file

    # Attach the generated image to the recipe using Active Storage
    # This saves the image to the configured storage service (local, S3, etc.)
    recipe.image.attach(
      io: image_file,
      filename: "recipe_#{recipe.id}_#{Time.current.to_i}.png",
      content_type: "image/png"
    )

    # Clean up tempfile
    image_file.close
    image_file.unlink

    # Reload recipe to ensure we have the latest image attachment data
    recipe.reload

    # Broadcast Turbo Stream update to refresh the image in the view
    # This allows the image to appear without requiring a page refresh
    broadcast_image_update(recipe)
  rescue StandardError => e
    # Log error for debugging
    # Image generation failures are non-critical - recipe still works without image
    Rails.logger.error("RecipeImageGenerationJob failed for recipe #{recipe_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    # Re-raise to trigger retry mechanism
    raise
  end

  private

  # Broadcast Turbo Stream update to refresh the image in the UI
  # This allows the image to appear without requiring a page refresh
  #
  # @param recipe [Recipe] The recipe that was updated
  def broadcast_image_update(recipe)
    # Use Turbo Streams to update the image in the view
    # This will replace the loading placeholder with the actual image
    # The stream is broadcast to all users viewing this recipe
    Turbo::StreamsChannel.broadcast_replace_to(
      "recipe_#{recipe.id}",
      target: "recipe-image-#{recipe.id}",
      partial: "recipes/image",
      locals: { recipe: recipe }
    )
  rescue StandardError => e
    # Log but don't fail - image is attached even if broadcast fails
    Rails.logger.warn("Failed to broadcast image update: #{e.message}")
  end
end
