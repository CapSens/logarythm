require 'socket.io-client-simple'
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
    attr_accessor :application_uuid
    attr_accessor :application_envs

    def initialize
      @application_uuid = nil
      @application_envs = nil
    end
  end

  class Railtie < Rails::Railtie
    config.after_initialize do
      begin
        def deep_simplify_record hsh
          hsh.keep_if do |h, v|
            if v.is_a?(Hash)
              deep_simplify_record(v)
            else
              v.is_a?(String) || v.is_a?(Integer)
            end
          end
        end

        configuration = Logarythm.configuration

        if configuration.present?
          configuration_options = [
            :application_uuid,
            :application_envs,
          ].map { |option| configuration.send(option).present? }.exclude?(false)

          if configuration_options && configuration.application_envs.select { |_| _[:name] == Rails.env.to_sym }.any?
            socket = SocketIO::Client::Simple.connect 'https://blooming-sands-8356.herokuapp.com'

            socket.on :connect do
              socket.emit :data, {
                id: configuration.application_uuid,
                action: :envs,
                content: { data: Base64.encode64(configuration.application_envs.to_json) }
              }

              ActiveSupport::Notifications.subscribe /sql|controller|view/ do |name, start, finish, id, payload|
                hash = {
                  id: configuration.application_uuid,
                  action: :log,
                  content: {
                    env: Rails.env,
                    name: name,
                    start: start,
                    finish: finish,
                    data: payload
                  }
                }

                Thread.new { socket.emit :data, hash }
              end
            end
          end
        end
      rescue Exception => e
        raise e
      end
    end
  end
end
