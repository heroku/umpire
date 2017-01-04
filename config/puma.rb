environment ENV['RACK_ENV'] || "development"
port ENV['PORT'] || 5000
quiet
threads ENV['PUMA_MIN_THREADS'] || 1, ENV['PUMA_MAX_THREADS'] || 16
workers ENV['PUMA_WORKERS'] || 3

preload_app!
Thread.abort_on_exception = true
