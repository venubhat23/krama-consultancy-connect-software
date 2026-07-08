namespace :dashboard do
  desc "Initialize dashboard optimizations"
  task initialize: :environment do
    puts "🚀 Initializing dashboard optimizations..."

    # 1. Create materialized view
    puts "📊 Creating materialized view..."
    begin
      ActiveRecord::Base.connection.execute('SELECT refresh_dashboard_stats_view()')
      puts "✅ Materialized view created/refreshed"
    rescue => e
      puts "⚠️  Materialized view setup failed: #{e.message}"
      puts "   Make sure to run: rails db:migrate"
    end

    # 2. Warm up cache
    puts "🔥 Warming up cache..."
    begin
      DashboardUltraFastService.preload_cache!
      puts "✅ Cache warmed successfully"
    rescue => e
      puts "⚠️  Cache warming failed: #{e.message}"
    end

    # 3. Start background cache warmer
    puts "⏰ Starting background cache warmer..."
    begin
      DashboardCacheWarmerJob.perform_later
      puts "✅ Background cache warmer started"
    rescue => e
      puts "⚠️  Background job failed: #{e.message}"
    end

    # 4. Test all cache layers
    puts "🧪 Testing cache layers..."
    health_status = DashboardPerformanceMonitor.health_check

    health_status.each do |layer, status|
      next if layer == :overall_status || layer == :total_check_time

      if status[:status] == :ok
        puts "✅ #{layer}: OK#{status[:response_time] ? " (#{status[:response_time].round(2)}ms)" : ""}"
      else
        puts "❌ #{layer}: #{status[:error]}"
      end
    end

    overall_status = health_status[:overall_status] == :healthy ? "✅ HEALTHY" : "❌ DEGRADED"
    total_time = health_status[:total_check_time].round(2)

    puts "\n🎯 Overall Status: #{overall_status} (#{total_time}ms)"

    # 5. Display performance recommendations
    puts "\n📈 Performance Recommendations:"
    recommendations = DashboardPerformanceMonitor.send(:get_performance_recommendations)
    recommendations.each { |rec| puts "   • #{rec}" }

    puts "\n🎉 Dashboard optimization setup complete!"
    puts "\n💡 Pro tips:"
    puts "   • Monitor performance: GET /dashboard/performance"
    puts "   • Check health: GET /dashboard/health"
    puts "   • Refresh cache: POST /dashboard/refresh_cache"
    puts "   • Run 'rake dashboard:benchmark' to test performance"
  end

  desc "Benchmark dashboard performance"
  task benchmark: :environment do
    puts "⚡ Benchmarking dashboard performance..."

    require 'benchmark'

    # Clear all caches first
    Rails.cache.clear
    Thread.current[:dashboard_tier_cache] = nil

    tests = [
      { name: "Full computation (cold)", method: -> { DashboardUltraFastService.fetch_stats } },
      { name: "Materialized view", method: -> { DashboardInstantService.fetch_stats } },
      { name: "Tiered cache (warm)", method: -> { DashboardTieredCacheService.fetch_stats(mode: :instant) } },
      { name: "Tiered cache (hot)", method: -> { DashboardTieredCacheService.fetch_stats(mode: :instant) } }
    ]

    results = []

    tests.each do |test|
      puts "\n🧪 Testing: #{test[:name]}"

      times = []
      5.times do |i|
        time = Benchmark.measure { test[:method].call }
        times << time.real * 1000
        print "   Run #{i+1}: #{(time.real * 1000).round(2)}ms\n"
      end

      avg_time = times.sum / times.size
      min_time = times.min
      max_time = times.max

      results << {
        name: test[:name],
        avg: avg_time.round(2),
        min: min_time.round(2),
        max: max_time.round(2)
      }

      puts "   📊 Average: #{avg_time.round(2)}ms (min: #{min_time.round(2)}ms, max: #{max_time.round(2)}ms)"
    end

    puts "\n📈 Performance Summary:"
    puts "   #{'Test'.ljust(25)} #{'Avg (ms)'.rjust(10)} #{'Min (ms)'.rjust(10)} #{'Max (ms)'.rjust(10)}"
    puts "   #{'-' * 55}"

    results.each do |result|
      puts "   #{result[:name].ljust(25)} #{result[:avg].to_s.rjust(10)} #{result[:min].to_s.rjust(10)} #{result[:max].to_s.rjust(10)}"
    end

    fastest = results.min_by { |r| r[:avg] }
    slowest = results.max_by { |r| r[:avg] }

    puts "\n🏆 Fastest: #{fastest[:name]} (#{fastest[:avg]}ms)"
    puts "🐌 Slowest: #{slowest[:name]} (#{slowest[:avg]}ms)"

    if slowest[:avg] > 0
      speedup = (slowest[:avg] / fastest[:avg]).round(1)
      puts "⚡ Speed improvement: #{speedup}x faster"
    end

    puts "\n✨ Benchmark complete!"
  end

  desc "Monitor dashboard performance in real-time"
  task monitor: :environment do
    puts "📡 Starting real-time dashboard monitoring..."
    puts "Press Ctrl+C to stop\n"

    trap('INT') do
      puts "\n🛑 Monitoring stopped"
      exit
    end

    loop do
      start_time = Time.current
      health = DashboardPerformanceMonitor.health_check
      load_time = (Time.current - start_time) * 1000

      status = health[:overall_status] == :healthy ? "✅" : "❌"
      timestamp = Time.current.strftime("%H:%M:%S")

      puts "#{timestamp} #{status} Health check: #{load_time.round(2)}ms"

      if health[:memory_cache]
        memory_time = health[:memory_cache][:response_time]&.round(2) || "N/A"
        puts "         Memory cache: #{memory_time}ms"
      end

      sleep 5
    end
  end

  desc "Refresh materialized view"
  task refresh_view: :environment do
    puts "🔄 Refreshing materialized view..."
    begin
      DashboardInstantService.refresh_materialized_view!
      puts "✅ Materialized view refreshed successfully"
    rescue => e
      puts "❌ Failed to refresh view: #{e.message}"
    end
  end

  desc "Clear all dashboard caches"
  task clear_cache: :environment do
    puts "🧹 Clearing all dashboard caches..."

    # Clear Rails cache
    Rails.cache.clear

    # Clear memory cache
    Thread.current[:dashboard_tier_cache] = nil

    # Clear any thread-local caches
    Thread.list.each do |thread|
      thread[:dashboard_tier_cache] = nil
    end

    puts "✅ All caches cleared"
  end
end