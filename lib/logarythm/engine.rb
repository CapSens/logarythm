module Logarythm
  class Engine < ::Rails::Engine
    isolate_namespace Logarythm
  end

  module ApplicationController
    def append_info_to_payload payload
        super
        payload[:session] = request.session.id rescue nil
    end
  end
end
