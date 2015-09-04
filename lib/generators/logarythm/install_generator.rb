module Logarythm
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)
      desc "Creates Logarythm initializer for your application"

      def copy_initializer
        template "logarythm_initializer.rb", "config/initializers/logarythm.rb"
      end
    end
  end
end
