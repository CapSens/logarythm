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
        def extract_status data, payload
          if (status = payload[:status])
            data[:status] = status.to_i
          elsif (error = payload[:exception])
            exception, message = error
            data[:status] = get_error_status_code(exception)
            data[:error] = "#{exception}: #{message}"
          else
            data[:status] = 0
          end
        end

        def get_error_status_code exception
          exception_object = exception.constantize.new
          exception_wrapper = ::ActionDispatch::ExceptionWrapper.new({}, exception_object)
          exception_wrapper.status_code
        end

        def compute_status payload
          status = payload[:status]
          if status.nil? && payload[:exception].present?
            exception_class_name = payload[:exception].first
            status = ActionDispatch::ExceptionWrapper.status_code_for_exception(exception_class_name)
          end
          status
        end

        def remove_if_file hsh
          hsh.keep_if do |h, v|
            v.is_a?(Hash) ? remove_if_file(v) : !v.is_a?(ActionDispatch::Http::UploadedFile)
          end
        end

        if ENV['APOCALYPTO_URL'].present?
          Redis.current = Redis.new url: ['redis://', ENV['APOCALYPTO_URL']].join
          ip_address = Socket.ip_address_list.detect{ |intf| intf.ipv4_private? }.ip_address

          ActiveSupport::Notifications.subscribe /sql|controller|view/ do |name, start, finish, id, payload|
            payload[:status] = compute_status(payload)

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
        end
      rescue Exception => e
        puts e.inspect
        raise e if Rails.env.development?
      end
    end
  end
end
