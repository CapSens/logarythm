require 'oj'
require 'redis'
require 'logarythm/engine'

module Logarythm
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration
    def initialize
    end
  end

  class Railtie < Rails::Railtie
    config.after_initialize do
      begin
        def remove_if_file hsh
          hsh.keep_if do |h, v|
            v.is_a?(Hash) ? remove_if_file(v) : !v.is_a?(ActionDispatch::Http::UploadedFile)
          end
        end

        Redis.current = Redis.new url: 'redis://ec2-52-29-10-23.eu-central-1.compute.amazonaws.com:6379'
        ip_address = Socket.ip_address_list.detect{ |intf| intf.ipv4_private? }.ip_address

        ActiveSupport::Notifications.subscribe /sql|controller|view/ do |name, start, finish, id, payload|
          hash = {
            action: :log,
            content: {
              env: Rails.env,
              name: name,
              start: start,
              finish: finish,
              data: remove_if_file(payload)
            }
          }

          Thread.new { Redis.current.publish ip_address, Oj.dump(hash, mode: :compat) }
        end
      rescue Exception => e
        raise e
      end
    end
  end
end
