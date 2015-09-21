require "logarythm/engine"

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
    attr_accessor :application_host

    def initialize
      @application_uuid = nil
      @application_envs = nil
      @application_host = nil
    end
  end

  class Railtie < Rails::Railtie
    config.after_initialize do

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
          :application_host
        ].map { |option| configuration.send(option).present? }.exclude?(false)

        if configuration_options && configuration.application_envs.include?(Rails.env.to_sym)
          redis = Redis.new url: ['redis://', configuration.application_host].join

          ActiveSupport::Notifications.subscribe /sql|controller|view/ do |name, start, finish, id, payload|
            redis.publish configuration.application_uuid, {
              content: {
                env: Rails.env,
                name: name,
                start: start,
                finish: finish,
                payload: (Base64.encode64(deep_simplify_record(payload).to_json) rescue nil)
              }
            }.to_json
          end
        end
      end
    end
  end
end
