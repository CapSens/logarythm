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
    attr_accessor :application_socket_id
    attr_accessor :application_socket_key
    attr_accessor :application_socket_secret

    def initialize
      @application_uuid          = nil
      @application_socket_id     = nil
      @application_socket_key    = nil
      @application_socket_secret = nil
    end
  end

  class Railtie < Rails::Railtie
    config.after_initialize do
      configuration = Logarythm.configuration

      if configuration.present?
        configuration_options = [
          :application_uuid,
          :application_socket_id,
          :application_socket_key,
          :application_socket_secret
        ].map { |option| configuration.send(option).present? }.exclude?(false)

        if configuration_options && [:development, :staging, :production].include?(Rails.env.to_sym)
          Pusher.app_id = configuration.application_socket_id
          Pusher.key    = configuration.application_socket_key
          Pusher.secret = configuration.application_socket_secret

          ActiveSupport::Notifications.subscribe /process_action.action_controller/ do |name, start, finish, id, payload|
            Pusher.trigger_async(configuration.application_uuid, 'process_action.action_controller', { content: { env: Rails.env, name: name, start: start, finish: finish, payload: payload.to_json } })
          end

          ActiveSupport::Notifications.subscribe /sql.active_record/ do |name, start, finish, id, payload|
            Pusher.trigger_async(configuration.application_uuid, 'sql.active_record', { content: { env: Rails.env, name: name, start: start, finish: finish, payload: payload.to_json } })
          end

          ActiveSupport::Notifications.subscribe /render_template.action_view/ do |name, start, finish, id, payload|
            Pusher.trigger_async(configuration.application_uuid, 'render_template.action_view', { content: { env: Rails.env, name: name, start: start, finish: finish, payload: payload.to_json } })
          end
        end
      end
    end
  end
end
