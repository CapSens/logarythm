require 'redis'

class LogJob
  include SuckerPunch::Job

  def perform hash, configuration
    Redis.current ||= Redis.new url: ['redis://', configuration.application_host].join
    Redis.current.publish configuration.application_uuid, hash
  end
end