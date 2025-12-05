# Job Queue Setup Guide

This guide explains how to set up a proper job queue for background image generation.

## Current Setup

**Development**: Uses `:async` adapter (works immediately, no setup needed)
**Production**: Currently set to `:async` (needs to be changed for production)

## Quick Start (Development)

The `:async` adapter is already configured for development. It works out of the box - no additional setup needed! Jobs will process in a background thread.

## Production Setup Options

### Option 1: Solid Queue (Recommended for Rails 7.1+)

Solid Queue is a database-backed job queue that's perfect for Rails applications.

#### Setup Steps:

1. **Add the gem:**
   ```bash
   bundle add solid_queue
   ```

2. **Install Solid Queue:**
   ```bash
   rails solid_queue:install
   rails db:migrate
   ```

3. **Update production config:**
   ```ruby
   # config/environments/production.rb
   config.active_job.queue_adapter = :solid_queue
   ```

4. **Start the worker:**
   ```bash
   # In production, run as a separate process
   bundle exec rake solid_queue:start
   
   # Or use a process manager like systemd, supervisor, etc.
   ```

5. **Configure concurrency (optional):**
   Create `config/solid_queue.yml`:
   ```yaml
   dispatchers:
     - polling_interval: 1
       batch_size: 5  # Process 5 jobs per batch
   ```

### Option 2: Sidekiq (Popular Choice)

Sidekiq is a battle-tested job queue using Redis.

#### Setup Steps:

1. **Add the gem:**
   ```bash
   bundle add sidekiq
   ```

2. **Update production config:**
   ```ruby
   # config/environments/production.rb
   config.active_job.queue_adapter = :sidekiq
   ```

3. **Configure Sidekiq:**
   Create `config/sidekiq.yml`:
   ```yaml
   :concurrency: 5  # Process 5 jobs simultaneously
   ```

4. **Start Sidekiq:**
   ```bash
   bundle exec sidekiq
   ```

5. **Optional: Add Sidekiq Web UI:**
   Add to `config/routes.rb`:
   ```ruby
   require 'sidekiq/web'
   mount Sidekiq::Web => '/sidekiq'
   ```

### Option 3: Good Job (PostgreSQL-based)

Good Job is another PostgreSQL-based option.

#### Setup Steps:

1. **Add the gem:**
   ```bash
   bundle add good_job
   ```

2. **Install Good Job:**
   ```bash
   rails generate good_job:install
   rails db:migrate
   ```

3. **Update production config:**
   ```ruby
   # config/environments/production.rb
   config.active_job.queue_adapter = :good_job
   ```

4. **Start the worker:**
   ```bash
   bundle exec rake good_job:start
   ```

## Testing the Setup

1. **Create or update a recipe** - This should trigger image generation
2. **Check logs** - You should see job enqueue messages
3. **Verify job processing** - Check that images appear (may take 10-20 seconds)

## Monitoring

### With Solid Queue:
- Check database: `SELECT * FROM solid_queue_jobs;`
- View pending jobs: `SELECT COUNT(*) FROM solid_queue_jobs WHERE finished_at IS NULL;`

### With Sidekiq:
- Visit `/sidekiq` (if web UI is enabled)
- Check Redis: `redis-cli LLEN queue:default`

### With Good Job:
- Visit `/good_job` (if web UI is enabled)
- Check database: `SELECT * FROM good_jobs;`

## Troubleshooting

### Jobs Not Processing

1. **Check if worker is running:**
   ```bash
   # For Solid Queue
   ps aux | grep solid_queue
   
   # For Sidekiq
   ps aux | grep sidekiq
   ```

2. **Check job queue:**
   - Look for jobs in the database/Redis
   - Check for errors in logs

3. **Verify queue adapter:**
   ```ruby
   # In Rails console
   Rails.application.config.active_job.queue_adapter
   ```

### Jobs Failing

1. **Check logs** for error messages
2. **Verify API keys** are set correctly
3. **Check job retries** - Jobs retry 3 times automatically

## Development vs Production

- **Development**: `:async` adapter is fine - jobs process in background thread
- **Production**: Use `:solid_queue`, `:sidekiq`, or `:good_job` for reliability

The `:async` adapter is not recommended for production because:
- Jobs are lost on server restart
- No persistence
- Limited scalability

## Next Steps

1. For development: You're all set! The `:async` adapter works immediately.
2. For production: Choose one of the options above and follow the setup steps.

