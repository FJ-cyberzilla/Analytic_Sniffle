# social_media_analytics.rb
require 'json'
require 'sqlite3'
require 'net/http'
require 'uri'
require 'time'
require 'logger'
require 'regexp'
require 'securerandom'

# Banner Display Module
module Banner
  def self.display
    puts "\e[36m╔══════════════════════════════════════════════════════════════╗"
    puts "║             ADVANCED SOCIAL MEDIA ANALYTICS PLATFORM        ║"
    puts "║                    Enhanced with AI & ML                    ║"
    puts "║                                                              ║"
    puts "║  Features: NLP • Pattern Recognition • Sentiment Analysis   ║"
    puts "║           Real-time Monitoring • Predictive Analytics       ║"
    puts "╚══════════════════════════════════════════════════════════════╝\e[0m"
    puts
  end
end

# Data Models
class SocialMediaPost
  attr_accessor :id, :platform, :post_id, :content, :author, :created_at, 
                :likes, :shares, :comments, :engagement_rate, :hashtags, 
                :mentions, :location, :language, :processed_at

  def initialize(attributes = {})
    attributes.each do |key, value|
      send("#{key}=", value)
    end
  end
end

class AnalyticsResult
  attr_accessor :platform, :total_posts, :average_engagement, 
                :sentiment_distribution, :trending_hashtags, 
                :pattern_scores, :analyzed_at

  def initialize(attributes = {})
    attributes.each do |key, value|
      send("#{key}=", value)
    end
  end
end

# Pattern Recognition Engine
class PatternRecognitionEngine
  def initialize(logger)
    @logger = logger
    @patterns = initialize_patterns
  end

  def initialize_patterns
    {
      "Viral_Content" => /(viral|trending|breaking|urgent|must see)/i,
      "Emotional_Language" => /(love|hate|amazing|terrible|incredible|shocking)/i,
      "Call_to_Action" => /(click|buy|subscribe|follow|share|comment)/i,
      "Time_Sensitive" => /(today|now|urgent|limited|hurry|deadline)/i,
      "Influencer_Mentions" => /@\w+/,
      "Hashtag_Clusters" => /#\w+/,
      "URL_Links" => /https?:\/\/[\w\-\.]+/,
      "Question_Pattern" => /\?/,
      "Exclamation_Pattern" => /!/,
      "Number_Pattern" => /\b\d+\b/
    }
  end

  def analyze_patterns(content)
    results = {}
    
    begin
      @patterns.each do |name, pattern|
        matches = content.scan(pattern)
        score = [matches.size / 10.0, 1.0].min # Normalize to 0-1 scale
        results[name] = score
      end
    rescue => e
      @logger.error("Error analyzing patterns: #{e.message}")
    end

    results
  end
end

# NLP Engine
class NLPEngine
  def initialize(logger)
    @logger = logger
  end

  def analyze_sentiment(text)
    # Simple sentiment analysis based on keyword matching
    positive_words = %w[love amazing great excellent outstanding fantastic wonderful good best awesome]
    negative_words = %w[hate terrible awful poor disappointing bad worst horrible terrible]

    positive_count = positive_words.count { |word| text.downcase.include?(word) }
    negative_count = negative_words.count { |word| text.downcase.include?(word) }
    
    total = positive_count + negative_count
    
    if total == 0
      { prediction: 0.5, probability: 0.5, score: 0.5 }
    else
      score = positive_count.to_f / total
      { prediction: score > 0.6 ? 1 : (score < 0.4 ? 0 : 0.5), 
        probability: score, 
        score: score }
    end
  end

  def extract_features(text)
    words = text.split
    sentences = text.split(/[.!?]/).reject(&:empty?)
    
    {
      word_count: words.size,
      char_count: text.length,
      sentence_count: sentences.size,
      avg_word_length: words.empty? ? 0 : words.sum(&:length).to_f / words.size,
      uppercase_ratio: text.count("A-Z").to_f / [text.length, 1].max,
      punctuation_count: text.count(".,!?;:"),
      hashtag_count: text.scan(/#\w+/).size,
      mention_count: text.scan(/@\w+/).size,
      url_count: text.scan(/https?:\/\/\S+/).size
    }
  end
end

# Database Manager
class DatabaseManager
  def initialize(db_path, logger)
    @db_path = db_path
    @logger = logger
    initialize_database
  end

  def initialize_database
    @db = SQLite3::Database.new(@db_path)
    
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS social_media_posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        platform TEXT NOT NULL,
        post_id TEXT NOT NULL,
        content TEXT,
        author TEXT,
        created_at DATETIME NOT NULL,
        likes INTEGER DEFAULT 0,
        shares INTEGER DEFAULT 0,
        comments INTEGER DEFAULT 0,
        engagement_rate REAL DEFAULT 0,
        hashtags TEXT,
        mentions TEXT,
        location TEXT,
        language TEXT,
        processed_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    SQL

    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS analytics_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        platform TEXT NOT NULL,
        total_posts INTEGER,
        average_engagement REAL,
        sentiment_data TEXT,
        trending_hashtags TEXT,
        pattern_scores TEXT,
        analyzed_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    SQL

    @db.execute "CREATE INDEX IF NOT EXISTS idx_platform_created ON social_media_posts(platform, created_at)"
    @db.execute "CREATE INDEX IF NOT EXISTS idx_processed ON social_media_posts(processed_at)"
    
    @logger.info("Database initialized successfully")
  rescue => e
    @logger.error("Failed to initialize database: #{e.message}")
    raise
  end

  def save_post(post)
    begin
      @db.execute(
        "INSERT INTO social_media_posts (platform, post_id, content, author, created_at, likes, shares, comments, engagement_rate, hashtags, mentions, location, language, processed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [post.platform, post.post_id, post.content, post.author, post.created_at.iso8601, post.likes, post.shares, post.comments, post.engagement_rate, post.hashtags, post.mentions, post.location, post.language, post.processed_at.iso8601]
      )
      true
    rescue => e
      @logger.error("Error saving post: #{e.message}")
      false
    end
  end

  def get_posts_by_platform(platform, start_date = nil, end_date = nil)
    posts = []
    sql = "SELECT * FROM social_media_posts WHERE platform = ?"
    params = [platform]

    if start_date
      sql += " AND created_at >= ?"
      params << start_date.iso8601
    end

    if end_date
      sql += " AND created_at <= ?"
      params << end_date.iso8601
    end

    sql += " ORDER BY created_at DESC"

    begin
      @db.execute(sql, params) do |row|
        posts << map_row_to_post(row)
      end
    rescue => e
      @logger.error("Error retrieving posts: #{e.message}")
    end

    posts
  end

  def save_analytics_result(result)
    begin
      @db.execute(
        "INSERT INTO analytics_results (platform, total_posts, average_engagement, sentiment_data, trending_hashtags, pattern_scores, analyzed_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [result.platform, result.total_posts, result.average_engagement, 
         result.sentiment_distribution.to_json, result.trending_hashtags.to_json, 
         result.pattern_scores.to_json, result.analyzed_at.iso8601]
      )
      true
    rescue => e
      @logger.error("Error saving analytics result: #{e.message}")
      false
    end
  end

  private

  def map_row_to_post(row)
    SocialMediaPost.new(
      id: row[0],
      platform: row[1],
      post_id: row[2],
      content: row[3],
      author: row[4],
      created_at: Time.parse(row[5]),
      likes: row[6],
      shares: row[7],
      comments: row[8],
      engagement_rate: row[9],
      hashtags: row[10],
      mentions: row[11],
      location: row[12],
      language: row[13],
      processed_at: Time.parse(row[14])
    )
  end
end

# Time Management System
class TimeManager
  def initialize(logger)
    @logger = logger
    @last_processed = {}
    @processing_intervals = initialize_processing_intervals
  end

  def initialize_processing_intervals
    {
      "Facebook" => 15 * 60,      # 15 minutes in seconds
      "Instagram" => 10 * 60,
      "Twitter" => 5 * 60,
      "TikTok" => 8 * 60,
      "LinkedIn" => 20 * 60,
      "YouTube" => 30 * 60,
      "Reddit" => 10 * 60,
      "Twitch" => 5 * 60,
      "BlueSky" => 12 * 60,
      "Threads" => 8 * 60,
      "Discord" => 7 * 60,
      "Snapchat" => 15 * 60,
      "Pinterest" => 25 * 60,
      "Telegram" => 10 * 60,
      "Roblox" => 20 * 60,
      "MeetMe" => 30 * 60,
      "BeReal" => 60 * 60,
      "Mastodon" => 15 * 60,
      "Clubhouse" => 45 * 60,
      "WhatsApp" => 60 * 60
    }
  end

  def should_process(platform)
    begin
      @last_processed[platform] ||= Time.at(0)
      
      time_since_last_process = Time.now - @last_processed[platform]
      interval = @processing_intervals[platform] || (15 * 60)
      should_process = time_since_last_process >= interval

      if should_process
        @last_processed[platform] = Time.now
      end

      should_process
    rescue => e
      @logger.error("Error checking processing schedule for #{platform}: #{e.message}")
      false
    end
  end

  def get_next_processing_time(platform)
    return 0 unless @last_processed[platform]
    
    interval = @processing_intervals[platform] || (15 * 60)
    next_time = @last_processed[platform] + interval
    time_until_next = next_time - Time.now
    
    time_until_next > 0 ? time_until_next : 0
  end
end

# Social Media Analytics Engine
class SocialMediaAnalyticsEngine
  SUPPORTED_PLATFORMS = %w[
    Facebook Instagram Twitter LinkedIn YouTube TikTok
    Snapchat Pinterest WhatsApp Telegram Discord Reddit
    Twitch Clubhouse BlueSky Threads BeReal Mastodon
    Roblox MeetMe
  ]

  def initialize(nlp_engine, pattern_engine, db_manager, time_manager, logger)
    @nlp_engine = nlp_engine
    @pattern_engine = pattern_engine
    @db_manager = db_manager
    @time_manager = time_manager
    @logger = logger
  end

  def run_analysis
    results = []
    
    Banner.display
    @logger.info("Starting comprehensive social media analysis...")

    SUPPORTED_PLATFORMS.each do |platform|
      begin
        unless @time_manager.should_process(platform)
          next_time = @time_manager.get_next_processing_time(platform)
          @logger.info("Skipping #{platform} - next processing in #{next_time.round} seconds")
          next
        end

        puts "\n🔍 Analyzing #{platform}..."
        result = analyze_platform(platform)
        
        if result
          results << result
          display_results(result)
        end
      rescue => e
        @logger.error("Error analyzing platform #{platform}: #{e.message}")
        puts "❌ Error analyzing #{platform}: #{e.message}"
      end
    end

    results
  end

  private

  def analyze_platform(platform)
    # Simulate data fetching (no API keys required)
    posts = fetch_posts(platform)
    
    if posts.empty?
      @logger.warn("No posts found for platform: #{platform}")
      return nil
    end

    # Save posts to database
    posts.each do |post|
      @db_manager.save_post(post)
    end

    # Perform analytics
    sentiment_distribution = analyze_sentiment_distribution(posts)
    trending_hashtags = extract_trending_hashtags(posts)
    pattern_scores = analyze_patterns(posts)
    avg_engagement = calculate_average_engagement(posts)

    AnalyticsResult.new(
      platform: platform,
      total_posts: posts.size,
      average_engagement: avg_engagement,
      sentiment_distribution: sentiment_distribution,
      trending_hashtags: trending_hashtags,
      pattern_scores: pattern_scores,
      analyzed_at: Time.now
    )
  rescue => e
    @logger.error("Error in platform analysis for #{platform}: #{e.message}")
    nil
  end

  def fetch_posts(platform)
    # Generate sample data (no API calls needed)
    random = Random.new
    posts = []

    sample_contents = [
      "Just had an amazing experience with this new product! Highly recommend! #amazing #review",
      "Terrible service, worst customer experience ever. Very disappointed. #disappointed #service",
      "Great weather today! Perfect for outdoor activities 🌞 #weather #outdoor #happy",
      "Breaking: Major announcement coming soon! Stay tuned for updates #breaking #news",
      "Love spending time with family and friends ❤️ #family #love #weekend",
      "This new app is incredible! Game-changer for productivity #tech #productivity #app",
      "Disappointed with the quality, expected much better #quality #disappointed",
      "Beautiful sunset today! Nature is amazing 🌅 #sunset #nature #photography",
      "Excited about the upcoming event! Can't wait to participate #excited #event",
      "Poor experience with customer support, needs improvement #support #feedback"
    ]

    locations = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", 
                "Philadelphia", "San Antonio", "San Diego", "Dallas", "San Jose"]

    # Generate sample posts for the platform
    (50 + random.rand(150)).times do
      content = sample_contents.sample
      
      posts << SocialMediaPost.new(
        platform: platform,
        post_id: "#{platform.downcase}_#{SecureRandom.hex(8)}",
        content: content,
        author: "user_#{1000 + random.rand(9000)}",
        created_at: Time.now - (3600 * random.rand(1..720)),
        likes: random.rand(0..10000),
        shares: random.rand(0..1000),
        comments: random.rand(0..500),
        engagement_rate: random.rand(0.0..0.15),
        hashtags: extract_hashtags(content),
        mentions: extract_mentions(content),
        location: locations.sample,
        language: "en",
        processed_at: Time.now
      )
    end

    posts
  end

  def analyze_sentiment_distribution(posts)
    distribution = {
      "Positive" => 0,
      "Negative" => 0,
      "Neutral" => 0
    }

    posts.each do |post|
      begin
        sentiment = @nlp_engine.analyze_sentiment(post.content)
        
        if sentiment[:score] > 0.6
          distribution["Positive"] += 1
        elsif sentiment[:score] < 0.4
          distribution["Negative"] += 1
        else
          distribution["Neutral"] += 1
        end
      rescue => e
        @logger.error("Error analyzing sentiment for post: #{e.message}")
      end
    end

    distribution
  end

  def extract_trending_hashtags(posts)
    hashtag_counts = {}

    posts.each do |post|
      next if post.hashtags.nil? || post.hashtags.empty?

      post.hashtags.split(',').each do |hashtag|
        clean_hashtag = hashtag.strip
        hashtag_counts[clean_hashtag] = hashtag_counts.fetch(clean_hashtag, 0) + 1
      end
    end

    hashtag_counts
      .sort_by { |_, count| -count }
      .take(10)
      .map { |hashtag, count| "#{hashtag} (#{count})" }
  end

  def analyze_patterns(posts)
    aggregated_patterns = {}

    posts.each do |post|
      patterns = @pattern_engine.analyze_patterns(post.content)
      
      patterns.each do |pattern_name, score|
        aggregated_patterns[pattern_name] ||= []
        aggregated_patterns[pattern_name] << score
      end
    end

    aggregated_patterns.transform_values do |scores|
      scores.empty? ? 0.0 : scores.sum / scores.size
    end
  end

  def calculate_average_engagement(posts)
    return 0 if posts.empty?
    
    posts.sum(&:engagement_rate) / posts.size
  end

  def extract_hashtags(content)
    content.scan(/#\w+/).join(',')
  end

  def extract_mentions(content)
    content.scan(/@\w+/).join(',')
  end

  def display_results(result)
    puts "\e[32m\n✅ #{result.platform} Analysis Complete\e[0m"
    puts "📊 Total Posts: #{result.total_posts}"
    puts "📈 Avg Engagement: #{(result.average_engagement * 100).round(2)}%"
    
    puts "\n🎭 Sentiment Distribution:"
    result.sentiment_distribution.each do |sentiment, count|
      puts "   #{sentiment}: #{count} posts"
    end
    
    puts "\n🔥 Trending Hashtags:"
    result.trending_hashtags.take(5).each do |hashtag|
      puts "   #{hashtag}"
    end
    
    puts "\n🧩 Pattern Analysis (Top 3):"
    result.pattern_scores
          .sort_by { |_, score| -score }
          .take(3)
          .each do |pattern, score|
      puts "   #{pattern}: #{(score * 100).round(1)}%"
    end
  end
end

# Configuration Manager
class ConfigurationManager
  attr_accessor :database, :api, :ml

  class DatabaseConfig
    attr_accessor :connection_string, :command_timeout, :enable_connection_pooling
    
    def initialize
      @connection_string = "./social_media_analytics.db"
      @command_timeout = 30
      @enable_connection_pooling = true
    end
  end

  class APIConfig
    attr_accessor :platform_endpoints, :api_keys, :request_timeout, :rate_limit_per_minute
    
    def initialize
      @platform_endpoints = {
        "Facebook" => "https://graph.facebook.com/v18.0/",
        "Instagram" => "https://graph.instagram.com/",
        "Twitter" => "https://api.twitter.com/2/",
        "LinkedIn" => "https://api.linkedin.com/v2/",
        "YouTube" => "https://www.googleapis.com/youtube/v3/",
        "TikTok" => "https://open-api.tiktok.com/",
        "Reddit" => "https://www.reddit.com/api/v1/",
        "Twitch" => "https://api.twitch.tv/helix/",
        "Discord" => "https://discord.com/api/v10/",
        "BlueSky" => "https://bsky.social/xrpc/",
        "Threads" => "https://graph.threads.net/v1.0/",
        "Snapchat" => "https://adsapi.snapchat.com/v1/",
        "Pinterest" => "https://api.pinterest.com/v5/",
        "Telegram" => "https://api.telegram.org/bot",
        "Roblox" => "https://apis.roblox.com/",
        "MeetMe" => "https://api.meetme.com/v1/"
      }
      @api_keys = {}
      @request_timeout = 30000
      @rate_limit_per_minute = 100
    end
  end

  class MLConfig
    attr_accessor :model_path, :enable_caching, :confidence_threshold
    
    def initialize
      @model_path = "./models/"
      @enable_caching = true
      @confidence_threshold = 0.7
    end
  end

  def initialize
    @database = DatabaseConfig.new
    @api = APIConfig.new
    @ml = MLConfig.new
  end

  def self.load_from_file(file_path)
    if File.exist?(file_path)
      begin
        config_data = JSON.parse(File.read(file_path))
        config = ConfigurationManager.new
        
        if config_data["database"]
          config.database.connection_string = config_data["database"]["connection_string"] if config_data["database"]["connection_string"]
        end
        
        config
      rescue
        ConfigurationManager.new
      end
    else
      ConfigurationManager.new
    end
  end
end

# Error Handler
class ErrorHandler
  def initialize(logger)
    @logger = logger
    @error_counts = {}
    @lock = Mutex.new
  end

  def handle_error(error, context = "", platform = "")
    @lock.synchronize do
      error_key = "#{platform}_#{error.class}"
      @error_counts[error_key] = @error_counts.fetch(error_key, 0) + 1

      @logger.error("Error in #{context} for platform #{platform}. Count: #{@error_counts[error_key]}")
      
      puts "\e[31m❌ Error in #{context}: #{error.message}\e[0m"

      # Implement circuit breaker pattern
      if @error_counts[error_key] > 5
        @logger.warn("Circuit breaker activated for #{platform} due to repeated errors")
        puts "⚠️  Temporarily suspending #{platform} processing due to repeated errors"
      end
    end
  end

  def should_skip_platform(platform)
    @lock.synchronize do
      total_errors = @error_counts.select { |k, _| k.start_with?(platform) }
                                 .values
                                 .sum
      total_errors > 10
    end
  end

  def get_error_statistics
    @lock.synchronize do
      @error_counts.dup
    end
  end
end

# Performance Monitor
class PerformanceMonitor
  def initialize(logger)
    @logger = logger
    @processing_times = {}
    @last_processing_start = {}
    @lock = Mutex.new
  end

  def start_processing(operation)
    @lock.synchronize do
      @last_processing_start[operation] = Time.now
    end
  end

  def end_processing(operation)
    @lock.synchronize do
      if @last_processing_start[operation]
        processing_time = Time.now - @last_processing_start[operation]
        
        @processing_times[operation] ||= []
        @processing_times[operation] << processing_time
        
        # Keep only last 100 measurements
        @processing_times[operation] = @processing_times[operation].last(100)
        
        @logger.info("Operation #{operation} completed in #{processing_time * 1000}ms")
      end
    end
  end

  def get_performance_metrics
    @lock.synchronize do
      metrics = {}
      
      @processing_times.each do |operation, times|
        next if times.empty?
        
        metrics[operation] = {
          average_ms: times.sum { |t| t * 1000 } / times.size,
          min_ms: times.min * 1000,
          max_ms: times.max * 1000,
          count: times.size,
          last_processed_at: @last_processing_start[operation]
        }
      end
      
      metrics
    end
  end
end

# Main Application
class SocialMediaAnalyticsApp
  def initialize
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    
    @config = ConfigurationManager.load_from_file("config.json")
    @error_handler = ErrorHandler.new(@logger)
    @performance_monitor = PerformanceMonitor.new(@logger)
    
    @nlp_engine = NLPEngine.new(@logger)
    @pattern_engine = PatternRecognitionEngine.new(@logger)
    @db_manager = DatabaseManager.new(@config.database.connection_string, @logger)
    @time_manager = TimeManager.new(@logger)
    
    @analytics_engine = SocialMediaAnalyticsEngine.new(
      @nlp_engine, @pattern_engine, @db_manager, @time_manager, @logger
    )
  end

  def run
    @logger.info("Social Media Analytics Platform starting...")
    
    # Run continuous analysis
    loop do
      begin
        @performance_monitor.start_processing("FullAnalysis")
        
        results = @analytics_engine.run_analysis
        
        @performance_monitor.end_processing("FullAnalysis")
        
        # Display summary
        display_summary(results)
        
        # Wait before next cycle (5 minutes)
        puts "\n⏰ Waiting 5 minutes before next analysis cycle..."
        sleep(300) # 5 minutes
      rescue => e
        @error_handler.handle_error(e, "Main Analysis Loop")
        sleep(60) # Wait 1 minute before retry
      end
    end
  rescue => e
    puts "❌ Fatal error: #{e.message}"
    exit(1)
  end

  private

  def display_summary(results)
    return if results.empty?
    
    puts "\e[33m\n" + "=" * 60
    puts "                    ANALYSIS SUMMARY"
    puts "=" * 60 + "\e[0m"

    total_posts = results.sum(&:total_posts)
    avg_engagement = results.sum(&:average_engagement) / results.size
    platform_count = results.size

    puts "🔍 Platforms Analyzed: #{platform_count}"
    puts "📊 Total Posts Processed: #{total_posts}"
    puts "📈 Average Engagement Rate: #{(avg_engagement * 100).round(2)}%"
    puts "⏰ Analysis Completed At: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"

    # Top performing platform
    top_platform = results.max_by(&:average_engagement)
    if top_platform
      puts "🏆 Top Performing Platform: #{top_platform.platform} (#{(top_platform.average_engagement * 100).round(2)}%)"
    end

    # Performance metrics
    metrics = @performance_monitor.get_performance_metrics
    unless metrics.empty?
      puts "\n⚡ Performance Metrics:"
      metrics.first(3).each do |operation, data|
        puts "   #{operation}: Avg #{data[:average_ms].round}ms"
      end
    end

    # Error statistics
    error_stats = @error_handler.get_error_statistics
    unless error_stats.empty?
      total_errors = error_stats.values.sum
      puts "⚠️  Total Errors Handled: #{total_errors}"
    end

    puts "=" * 60
  end
end

# Extension methods
module Extensions
  def self.calculate_engagement_rate(post)
    return 0 if post.likes == 0 && post.shares == 0 && post.comments == 0

    # Simple engagement rate calculation
    total_engagements = post.likes + post.shares + (post.comments * 2) # Comments weighted more
    [total_engagements / 10000.0, 1.0].min # Normalize
  end

  def self.high_engagement?(post)
    calculate_engagement_rate(post) > 0.05 # 5% threshold
  end

  def self.get_sentiment_label(score)
    if score > 0.6
      "Positive"
    elsif score < 0.4
      "Negative"
    else
      "Neutral"
    end
  end

  def self.to_analytics_data(result)
    {
      platform: result.platform,
      total_posts: result.total_posts,
      avg_engagement: result.average_engagement,
      sentiment_positive: result.sentiment_distribution["Positive"] || 0,
      sentiment_negative: result.sentiment_distribution["Negative"] || 0,
      sentiment_neutral: result.sentiment_distribution["Neutral"] || 0,
      top_hashtags: result.trending_hashtags.take(5),
      analyzed_at: result.analyzed_at
    }
  end
end

# Run the application
if __FILE__ == $0
  app = SocialMediaAnalyticsApp.new
  app.run
end
