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
            :application_host
          ].map { |option| configuration.send(option).present? }.exclude?(false)

          if configuration_options && configuration.application_envs.include?(Rails.env.to_sym)
            Redis.current = Redis.new url: ['redis://', configuration.application_host].join

            repo = Git.open Rails.root
            commits = repo.log.map { |log| { date: log.date, sha: log.sha, message: log.message, author: { name: log.author.name, email: log.author.email } } }.to_json
            LogJob.new.async.perform({ content: { name: :commits, env: Rails.env, payload: Base64.encode64(commits) } }.to_json, configuration)

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
