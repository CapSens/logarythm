class LogJob
  include SuckerPunch::Job
  workers 10

  def perform configuration, hash
    Redis.current.publish configuration.application_uuid, hash.to_json
  end
end
