class LogJob
  include SuckerPunch::Job

  def perform socket, hash
    socket.emit :data, hash
  end
end
