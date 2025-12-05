# Recipe Image Generation Setup

This document explains how image generation works for recipes using RubyLLM.

## Overview

Recipe images are generated asynchronously using RubyLLM's `paint` method (DALL-E 3). The system is designed to:
- Generate images **after** recipe completion to ensure accuracy
- Display recipes immediately with a loading placeholder
- Process images in the background without blocking requests
- Support parallelization for multiple recipes

## How It Works

### Flow

1. **User sends message** → Recipe generation starts (blocking, ~5-15 seconds)
2. **Recipe generation completes** → Recipe displayed immediately with image loading placeholder
3. **Background job enqueued** → `RecipeImageGenerationJob` starts processing
4. **Image generation** → RubyLLM.paint generates image based on final recipe data (~10-20 seconds)
5. **Image appears automatically** → Turbo Stream broadcast updates the view in real-time (no page refresh needed)

### Components

1. **Recipe Model** (`app/models/recipe.rb`)
   - Has Active Storage attachment: `has_one_attached :image`

2. **RecipeImageGenerationJob** (`app/jobs/recipe_image_generation_job.rb`)
   - Uses `RubyLLM.paint` to generate images
   - Builds prompts from recipe title, description, and ingredients
   - Downloads and attaches images via Active Storage
   - Broadcasts Turbo Stream update when image is ready
   - Retries on failure (3 attempts with polynomial backoff)

3. **Controller** (`app/controllers/recipes_controller.rb`)
   - Triggers job after recipe update (only if recipe was modified)
   - Only generates if image doesn't already exist

4. **Views**
   - `app/views/recipes/_image.html.erb` - Image partial with loading state (uses `rails_blob_path` for proper URLs)
   - `app/views/recipes/_details.html.erb` - Includes image partial
   - `app/views/recipes/show.html.erb` - Subscribes to Turbo Stream updates via `turbo_stream_from`

5. **Turbo Streams Integration**
   - Real-time updates when images are generated
   - No page refresh required
   - Uses WebSocket connection via ActionCable

## Setup

### 1. Ensure Active Storage is Configured

Active Storage should already be set up. If not:

```bash
rails active_storage:install
rails db:migrate
```

### 2. Configure RubyLLM

Make sure RubyLLM is configured with your OpenAI API key:

```ruby
# config/initializers/ruby_llm.rb (if it exists)
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
end
```

Or set the environment variable:
```bash
# In .env file
OPENAI_API_KEY=your_api_key_here
```

### 3. Configure Background Job Processing

For parallelization, you need a proper job queue. Options:

#### Option A: Solid Queue (Rails 7.1+ Default)

```ruby
# config/application.rb or config/environments/production.rb
config.active_job.queue_adapter = :solid_queue
```

Then:
```bash
rails solid_queue:install
rails db:migrate
rails solid_queue:start
```

#### Option B: Sidekiq (Recommended for Production)

Add to `Gemfile`:
```ruby
gem 'sidekiq'
```

Configure:
```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
```

Start Sidekiq:
```bash
bundle exec sidekiq
```

## Image Generation Details

### Prompt Generation

The job builds prompts from:
- Recipe title
- Recipe description
- First 3 ingredients

Example prompt:
```
"Professional food photography of Chocolate Chip Pancakes, fluffy golden pancakes with melted chocolate chips. Featuring flour, eggs, milk, chocolate chips. High quality, appetizing, well-lit, restaurant style food photography"
```

### Image Parameters

Current implementation uses:
- Model: `dall-e-3` (default, can be customized)

**Note**: RubyLLM.paint currently only supports the `model` parameter. Parameters like `size`, `quality`, and `style` are not supported in the current RubyLLM version.

### Customization

To customize the model, modify the job call in the controller:

```ruby
RecipeImageGenerationJob.perform_later(
  @recipe.id,
  {
    model: "dall-e-3"  # or other supported model
  }
)
```

## Parallelization

### How It Works

- Each recipe update enqueues a separate background job
- Job queue processes multiple jobs concurrently
- No blocking - requests return immediately

### Enabling Parallel Processing

#### With Sidekiq

Configure in `config/sidekiq.yml`:
```yaml
:concurrency: 5  # Process 5 jobs simultaneously
```

#### With Solid Queue

Configure in `config/solid_queue.yml`:
```yaml
dispatchers:
  - polling_interval: 1
    batch_size: 5
```

## UX Flow

### Timeline Example

```
T=0s:   User sends "make me pancakes"
T=8s:   Recipe generation completes
        → Recipe displayed immediately with loading image placeholder
        → Background job enqueued
        → WebSocket connection established (Turbo Streams)
T=20s:  Image generation completes
        → Image attached to recipe
        → Turbo Stream broadcast sent
        → Image appears automatically in view (no refresh needed!)
```

### Loading State

- Shows spinner and "Generating recipe image..." message
- Only appears when recipe has content but no image yet
- Automatically replaced when image is ready via Turbo Stream update
- Uses relative image paths (`rails_blob_path`) so URLs work correctly in broadcasts

## Error Handling

- Jobs retry up to 3 times on failure
- Errors are logged but don't crash the application
- Recipe works fine without image (graceful degradation)
- Check logs for detailed error messages

## Testing

1. Ensure `OPENAI_API_KEY` is set
2. Create or update a recipe
3. Check job queue to see job processing
4. Verify image appears automatically (should update in real-time via Turbo Streams)
5. Check browser console for WebSocket connection (should see connection to `/cable`)

## Troubleshooting

### Images Not Generating

1. Check `OPENAI_API_KEY` is set correctly
2. Verify job queue is running
3. Check job logs for errors
4. Ensure Active Storage is configured
5. Verify RubyLLM.paint is returning a valid RubyLLM::Image object

### Images Not Appearing Automatically

1. Check browser console for WebSocket connection errors
2. Verify `turbo_stream_from` is in the view (should be in `show.html.erb`)
3. Check server logs for Turbo Stream broadcast messages
4. Ensure ActionCable/Turbo Streams is properly configured (should work with turbo-rails)
5. Verify image URL is using relative path (`rails_blob_path`) not absolute URL

### Jobs Not Processing

1. Verify job queue adapter is configured
2. Ensure worker process is running
3. Check for job failures in queue

### Rate Limit Errors

1. Reduce concurrent job processing
2. Add delays between job executions
3. Check OpenAI API rate limits

## Technical Details

### Image URL Generation

The image partial uses `rails_blob_path` to generate relative paths. This ensures:
- URLs work correctly in background job broadcasts (no request context)
- Browser automatically uses current page's host
- No hardcoded `http://example.org` placeholder URLs

### Turbo Streams Implementation

- Uses `turbo_stream_from "recipe_#{recipe.id}"` in the view to subscribe to updates
- Job broadcasts via `Turbo::StreamsChannel.broadcast_replace_to`
- Updates the `recipe-image-{id}` target element automatically
- Works via WebSocket connection (ActionCable)

### RubyLLM Integration

- Uses `RubyLLM.paint(prompt, model: "dall-e-3")` 
- Returns `RubyLLM::Image` object with `.url` method
- Handles both URL and base64 image responses
- Downloads images using `open-uri` (with Net::HTTP fallback)

## Future Enhancements

- Image regeneration on recipe updates (currently only generates once)
- Multiple image variants (different sizes/styles)
- Image caching and optimization
- Support for other image generation providers
- Image editing/regeneration UI

