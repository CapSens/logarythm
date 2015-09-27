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
    attr_accessor :application_uuid
    attr_accessor :application_host
    attr_accessor :application_envs

    def initialize
      @application_uuid = nil
      @application_host = nil
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
            :application_host,
            :application_envs,
          ].map { |option| configuration.send(option).present? }.exclude?(false)

          if configuration_options && configuration.application_envs.select { |_| _[:name] == Rails.env.to_sym }.any?
            Redis.current = Redis.new url: ['redis://h:', configuration.application_host].join

            LogJob.new.async.perform({ content: { name: :envs, env: Rails.env, payload: Base64.encode64(configuration.application_envs.to_json) }}.to_json, configuration)
            ActiveSupport::Notifications.subscribe /sql|controller|view/ do |name, start, finish, id, payload|
              hash = {
                content: {
                  env: Rails.env,
                  name: name,
                  start: start,
                  finish: finish,
                  payload: (Base64.encode64(deep_simplify_record(payload).to_json) rescue nil)
                }
              }.to_json

              LogJob.new.async.perform hash, configuration
            end
          end
        end
      rescue Exception => e
        raise e
      end
    end
  end
end
