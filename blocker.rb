require 'open3'

# Script for blocking malicious IPs from https://github.com/stamparm/ipsum
# using GCP compute firewall
class Blocker
  attr_accessor :key_file, :project, :ip_url, :description
  attr_accessor :base_name, :time_stamp, :rule_name

  BASE_URL = 'https://raw.githubusercontent.com/stamparm/ipsum/master/levels/'.freeze
  BASE_NAME = 'gcp-ip-blocker'.freeze
  DESCRIPTION = 'Auto-generated by gcp-ip-blocker'.freeze
  REQUIRED_ENVS = %w[
    IP_LEVEL
    KEY_FILE
    PROJECT
  ].freeze

  def initialize
    check_required_envs
    set_instance_vars
    gcloud_auth
    gcloud_set_project
  end

  def run
    puts 'Creating new firewall rules'
    batch_create_firewall_rule
    puts 'All new firewall rules created'
    puts 'Deleting other firewall rules created by gcp-ip-blocker'
    delete_firewall_rule(list_firewall_rule(rule_name))
    puts 'All other firewall rules created by gcp-ip-blocker deleted'
    puts "#{ip_pool.size} IPs was blocked"
  end

  private

  def set_instance_vars
    ip_level = ENV['IP_LEVEL']
    self.ip_url = "#{BASE_URL}#{ip_level}.txt"
    self.key_file = ENV['KEY_FILE']
    self.project = ENV['PROJECT']
    self.description = DESCRIPTION
    self.base_name = BASE_NAME
    self.time_stamp = Time.now.strftime('%s')
    self.rule_name = %(#{base_name}-#{time_stamp})
  end

  def rule_name_with_index(index)
    %(#{rule_name}-#{format('%02d', index)})
  end

  def check_required_envs
    REQUIRED_ENVS.each do |env|
      check_env(env)
    end
    true
  end

  def check_env(env)
    ENV[env] || abort("Environment variable #{env} is required")
    true
  end

  def gcloud_auth
    cmd = %(gcloud auth activate-service-account --key-file="#{key_file}")
    stdout, stderr, s = ::Open3.capture3(cmd)
    s.success? || abort("Fail to do gcloud auth:\n#{stdout}\n#{stderr}")
  end

  def gcloud_set_project
    cmd = %(gcloud config set project "#{project}")
    stdout, stderr, s = ::Open3.capture3(cmd)
    s.success? || abort("Fail to set gcloud project:\n#{stdout}\n#{stderr}")
  end

  def ip_pool
    return @ip_pool if @ip_pool

    cmd = %(curl -sS --compressed "#{ip_url}")
    stdout, stderr, s = ::Open3.capture3(cmd)
    s.success? || abort("Fail to get malicious IPs:\n#{stdout}\n#{stderr}")
    @ip_pool = stdout.split("\n")
  end

  def create_cmd(name, ips)
    base = %(gcloud compute firewall-rules create "#{name}" )
    options = %w[
      --action=DENY
      --rules=all
      --direction=INGRESS
    ] + [
      %(--source-ranges="#{ips.join(',')}"),
      %(--description="#{description}")
    ]
    base + options.join(' ')
  end

  def batch_create_firewall_rule
    ip_pool.each_slice(256).with_index do |ips, index|
      puts "Creating new firewall rules (batch #{index})"
      create_firewall_rule(rule_name_with_index(index), ips)
    end
  end

  def create_firewall_rule(name, ips)
    stdout, stderr, s = ::Open3.capture3(create_cmd(name, ips))
    s.success? || abort("Fail to create firewall rule:\n#{stdout}\n#{stderr}")
  end

  def list_firewall_rule(name)
    base = %(gcloud compute firewall-rules list )
    filter_str = %(description~'#{description}' AND NOT name~'#{name}')
    options = %w[
      --format="value(name)"
    ] + [%(--filter="#{filter_str}")]
    cmd = base + options.join(' ')
    stdout, stderr, s = ::Open3.capture3(cmd)
    s.success? || abort("Fail to list firewall rule:\n#{stdout}\n#{stderr}")
    stdout.split("\n")
  end

  def delete_firewall_rule(names)
    base = %(gcloud compute firewall-rules delete )
    cmd = base + names.join(' ')
    stdout, stderr, s = ::Open3.capture3(cmd)
    s.success? || abort("Fail to delete firewall rule:\n#{stdout}\n#{stderr}")
  end
end

Blocker.new.run
