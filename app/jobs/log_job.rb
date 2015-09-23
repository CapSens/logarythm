class LogJob
  include SuckerPunch::Job

  def perform hash, configuration
    Redis.current.publish configuration.application_uuid, hash
  end
end