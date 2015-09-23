require 'redis'

class LogJob
  include SuckerPunch::Job

  def perform hash, configuration
    @redis ||= Redis.new url: ['redis://', configuration.application_host].join
    @redis.publish configuration.application_uuid, hash
  end
end