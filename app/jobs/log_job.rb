class LogJob
  include SuckerPunch::Job
  workers 1

  def perform socket, hash
    ActiveRecord::Base.connection_pool.with_connection do
      socket.emit :data, hash
    end
  end
end
