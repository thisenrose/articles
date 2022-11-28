require "uri"
require "net/http"

namespace :ci do
  desc "Optimze setup"

  MAX_LOAD_GROUPS_ATTEMPTS = 3
  DELAY_IN_SECONDS_BETWEEEN_LOAD_GROUPS_ATTEMPTS = 5

  def raise_failed_to_load_groups
    raise "Failed to load groups"
  end

  def load_groups(args)
    spec_file = File.read("rspec_time_runs.json")
    specs = JSON.parse(spec_file)

    url = URI("#{ENV['RSPEC_GROUPER_SERVICE_URL']}/groups")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(url)
    request["content-type"] = "application/json"
    request.body = { total_groups: (args[:total_groups] || 16).to_i, specs: specs }.to_json

    response = http.request(request)
    raise_failed_to_load_groups if response.code != "200"

    JSON.parse(response.read_body)
  end

  def safe_load_groups(args)
    (1..MAX_LOAD_GROUPS_ATTEMPTS).each do |attempt|
      begin
        return load_groups(args)
      rescue
        sleep(DELAY_IN_SECONDS_BETWEEEN_LOAD_GROUPS_ATTEMPTS.seconds)
      end
    end

    raise_failed_to_load_groups
  end


  # Roda osum determinado grupo
  task :load_specs_of_group, [:total_groups, :group] do |t, args|
    groups = safe_load_groups(args)
    specs = (groups[args[:group].to_i] || { "specs" => [] })["specs"]
    spec_ids = specs.map { |spec| spec["id"] }
    puts(spec_ids.join(" "))
  end

  task :send_specs_run_times do
    spec_file = File.read("rspec_time_runs.json")
    specs = JSON.parse(spec_file)

    url = URI("#{ENV['RSPEC_GROUPER_SERVICE_URL']}/write_run_times")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(url)
    request["content-type"] = "application/json"
    request.body = { specs: specs }.to_json
    response = http.request(request)
    puts(response.code)
  end
end
