# Image Generation Strategy Pattern

This document explains the strategy pattern implementation for image generation, which allows switching between real image generation (RubyLLM.paint) and stub implementations for testing/development.

## Overview

The image generation system uses a strategy pattern to support both:
- **Real Image Generation**: Uses RubyLLM.paint with DALL-E 3 to generate actual recipe images
- **Stub Image Generation**: Creates placeholder images for testing/development without wasting tokens

## Architecture

### Strategy Pattern Components

1. **BaseStrategy** (`app/lib/image_generators/base_strategy.rb`)
   - Abstract base class defining the interface
   - All strategies must implement `generate(recipe, options)`
   - Provides shared `build_image_prompt(recipe)` method

2. **RealImageGenerator** (`app/lib/image_generators/real_image_generator.rb`)
   - Uses RubyLLM.paint to generate actual images
   - Downloads/decodes images from URLs or base64 data
   - Full implementation of real image generation

3. **StubImageGenerator** (`app/lib/image_generators/stub_image_generator.rb`)
   - Creates placeholder images using ChunkyPNG
   - Delays 1 second to simulate real generation time
   - Generates a warm-colored gradient rectangle
   - Falls back to minimal PNG if ChunkyPNG is unavailable

4. **Factory** (`app/lib/image_generators/factory.rb`)
   - Determines which strategy to use based on configuration
   - Checks `ENV['IMAGE_GENERATION_STRATEGY']` first
   - Falls back to environment-based defaults

## Configuration

### Environment Variable

Set `ENV['IMAGE_GENERATION_STRATEGY']` to control which strategy is used:

```bash
# Use real image generation (RubyLLM.paint)
export IMAGE_GENERATION_STRATEGY=real

# Use stub image generation (placeholder)
export IMAGE_GENERATION_STRATEGY=stub
```

### Default Behavior

- **Development/Test**: Defaults to `stub` (saves tokens, faster)
- **Production**: Defaults to `real` (actual image generation)

### Usage in Code

The `RecipeImageGenerationJob` automatically uses the factory to select the appropriate strategy:

```ruby
# In RecipeImageGenerationJob
image_generator = ImageGenerators::Factory.create
image_file = image_generator.generate(recipe, options)
```

## Stub Image Generator Details

### Features

- **1 Second Delay**: Simulates real image generation time
- **Gradient Background**: Warm orange/yellow food-themed colors
- **800x600 Image**: Standard recipe image dimensions
- **Fallback Support**: Creates minimal valid PNG if ChunkyPNG fails

### Dependencies

- **chunky_png**: Required for generating colored placeholder images
  - Installed via Gemfile
  - Falls back to minimal PNG if unavailable

## Switching Strategies

### For Development/Testing

By default, development uses stub generation. To explicitly set it:

```bash
export IMAGE_GENERATION_STRATEGY=stub
```

### For Production

Production defaults to real generation. To explicitly set it:

```bash
export IMAGE_GENERATION_STRATEGY=real
```

### Temporary Override

You can also override in code (not recommended for production):

```ruby
# Force stub in any environment
ENV['IMAGE_GENERATION_STRATEGY'] = 'stub'
```

## Benefits

1. **Token Savings**: Stub strategy doesn't call RubyLLM.paint, saving API tokens
2. **Faster Development**: Stub images generate in ~1 second vs ~10-20 seconds
3. **Testing**: Easy to test image generation flow without API calls
4. **Cost Control**: Can disable real image generation during development
5. **Flexibility**: Easy to switch between strategies via environment variable

## Implementation Details

### Strategy Interface

All strategies must implement:

```ruby
def generate(recipe, options = {})
  # Returns Tempfile with generated image
end
```

### Factory Pattern

The factory checks configuration in this order:

1. `ENV['IMAGE_GENERATION_STRATEGY']` (explicit override)
2. Environment-based defaults (development → stub, production → real)

### Error Handling

- Real generator: Raises errors (handled by job retry mechanism)
- Stub generator: Falls back to minimal PNG on any error

## Testing

To test the stub generator:

```ruby
# In Rails console
recipe = Recipe.first
generator = ImageGenerators::StubImageGenerator.new
image_file = generator.generate(recipe)
# image_file is a Tempfile with PNG data
```

To test the factory:

```ruby
# Default (development = stub)
ImageGenerators::Factory.create
# => #<ImageGenerators::StubImageGenerator>

# Explicit override
ENV['IMAGE_GENERATION_STRATEGY'] = 'real'
ImageGenerators::Factory.create
# => #<ImageGenerators::RealImageGenerator>
```

## Troubleshooting

### Stub Images Not Generating

1. Check that `chunky_png` gem is installed: `bundle install`
2. Verify factory is using stub: `ImageGenerators::Factory.create.class`
3. Check logs for fallback messages

### Real Images Not Generating

1. Verify `OPENAI_API_KEY` is set
2. Check `ENV['IMAGE_GENERATION_STRATEGY']` is not set to 'stub'
3. Review job logs for RubyLLM.paint errors

### Strategy Not Switching

1. Restart Rails server after changing `ENV['IMAGE_GENERATION_STRATEGY']`
2. Verify environment variable is set: `echo $IMAGE_GENERATION_STRATEGY`
3. Check factory default logic matches your environment

