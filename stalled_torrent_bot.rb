require "bundler/setup"
require "httparty"

class StalledTorrentBot
  QBIT_HOST = "http://qbittorrent:8080"

  CONFIG = {
    radarr: {
      port: 7878,
      api_key: ENV.fetch("RADARR_API_KEY")
    },
    sonarr: {
      port: 8989,
      api_key: ENV.fetch("SONARR_API_KEY")
    }
  }

  def initialize
    @queues = {}
    get_qbit_cookie
  end

  def run
    puts "Running at #{Time.now.strftime('%D %H:%M:%S')}"

    stalled_downloads.each do |download|
      stalled_time = (Time.now - Time.at(download["last_activity"])) / 60 / 60

      if stalled_time < 24
        puts "Skipping #{download['name']} - stalled #{stalled_time.round(1)} hours"
        next
      end

      case download["category"]
      when "sonarr"
        delete(:sonarr, download)
      when "radarr"
        delete(:radarr, download)
      else
        puts "Skipping #{download['name']} with category #{download['category']}"
      end
    end

    puts "Done."
  end

  private

  def get_qbit_cookie
    response = HTTParty.post(
      "#{QBIT_HOST}/api/v2/auth/login",
      body: {
        username: ENV.fetch("QBIT_USERNAME"),
        password: ENV.fetch("QBIT_PASSWORD")
      }
    )

    @qbit_cookie = response.headers["set-cookie"].split("; ").find { |str| str.start_with?("SID") }
  end

  def stalled_downloads
    downloads = HTTParty.get(
      "#{QBIT_HOST}/api/v2/torrents/info",
      headers: {
        Referer: QBIT_HOST,
        Cookie: @qbit_cookie
      }
    )

    downloads.select { |download| download["state"] == "stalledDL" }.tap do |stalled|
      puts "Found #{stalled.size} stalled downloads"
    end
  end

  def delete(kind, download)
    id = queue_id(kind, download)

    HTTParty.delete(
      "http://#{kind}:#{CONFIG[kind][:port]}/api/v3/queue/#{id}?blacklist=true",
      headers: { "X-Api-Key": CONFIG[kind][:api_key] }
    )
  end

  def queue_id(kind, hash)
    record = queue(kind).find { |entry| entry["downloadId"].downcase == hash.downcase }

    raise "No record found for #{hash}" if record.nil?

    record["id"]
  end

  def queue(kind)
    @queue[kind] ||= HTTParty.get(
      "http://#{kind}:#{CONFIG[kind][:port]}/api/v3/queue",
      headers: { "X-Api-Key": CONFIG[kind][:api_key] }
    )["records"]
  end
end

check_interval = ENV.fetch("SLEEP_MINUTES").to_i * 60
puts "Starting loop with interval of #{ENV.fetch('SLEEP_MINUTES')} minutes"

loop do
  StalledTorrentBot.new.run
  sleep check_interval
end
