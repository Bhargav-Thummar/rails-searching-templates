# Requirements:
# -------------
#
# * Git
# * Ruby  >= 2.7.0
# * Rails >= 7
# * ElasticSearch version 7.17.9

# =========================================== Execute This Template =================================================
# rails app:template LOCATION=templates/searchkick_search.rb

require 'uri'
require 'net/http'
require 'json'

# ============================================= System Settings ==================================================
# ======================================== Install Elastic Search Engine =========================================

unless (run 'sudo service elasticsearch status | grep running')
  say_status "ERROR", "Failed to start elasticsearch service \n\n", :red

  # ------------ install if Elasticsearch is not available ---------------
  begin      
    say_status "INFO", "Installing Elastic Search...---------\n\n", :yellow
    
    run 'sudo apt-get update'

    # Add the public GPG key to APT
    run 'curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -'

    # add the Elastic source list to the sources.list.d directory, where APT will search for new sources
    run 'echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list'

    # Install Elasticsearch with this command
    run 'sudo apt install elasticsearch'

    # Configuring Elasticsearch
    unless (run "sudo cat /etc/elasticsearch/elasticsearch.yml | grep 'network.host: localhost'")
      run "sudo sed -i -e '1inetwork.host: localhost\' /etc/elasticsearch/elasticsearch.yml"
    end

    # var/lib/elasticsearch is where elasticsearch stores data
    run 'sudo chown -R elasticsearch:elasticsearch /var/lib/elasticsearch'

    # /etc/elasticsearch is the place where configuration file for elasticsearch service and elasticsearch logs is stored
    run 'sudo chown -R elasticsearch:elasticsearch /etc/elasticsearch'

  rescue => e

    say_status "INFO", "Installing Elastic Search...---------\n\n"
    exit(1)
  end
end

# ==================================================================================================================




# ======================================= enable/restart the service ===============================================
run 'sudo service elasticsearch enable'
run 'sudo service elasticsearch restart'
# ==================================================================================================================




# ============================== Check if elasticsearch service is running properly ================================

$elasticsearch_url = ENV.fetch('ELASTICSEARCH_URL', 'http://localhost:9200')

begin
  if Net::HTTP.get(URI.parse($elasticsearch_url)).include?("elasticsearch")
    say_status "INFO", "Elastic Search engine running...---------\n\n"
  else
    say_status "ERROR", "Elastic Search engine not running!!!---------\n\n"
  end

rescue Errno::ECONNREFUSED => e
  say_status "ERROR", "Cannot connect to Elasticsearch on <#{$elasticsearch_url}>\n\n", :red
  exit(1)

rescue StandardError => e
  say_status "ERROR", "#{e.class}: #{e.message}", :red
  exit(1)
end

# ==================================================================================================================



# =========================================== Rails application Settings ============================================
# ============================================= Add gems into Gemfile ==============================================

say_status  "Rubygems", "Adding searchkick & elasticsearch libraries into Gemfile...\n", :yellow

gem_list = `gem list`.lines
gem 'searchkick'                      if gem_list.grep(/^searchkick \(.*\)/)
gem 'elasticsearch', "< 7.14"         if gem_list.grep(/^elasticsearch \(.*\)/)

# ==================================================================================================================




# ========================================== Set environment configuration =========================================

say_status  "Application", "Disabling asset logging in development...\n", :yellow

environment 'config.assets.logger = false', env: 'development'

# ==================================================================================================================





# ================================================= Install GEMS ===================================================

puts
say_status  "Rubygems", "Installing Rubygems...", :yellow

run "bundle install"

# ==================================================================================================================





# ================================ Add Elasticsearch integration into the interface ===============================
models = 
  [
    'Article'
  ]

models.each do |model_name|
  class_name = model_name.underscore
  model_name_pluralize = model_name.pluralize
  class_name_pluralize = class_name.pluralize


  # ------------------------------------ make require changes in model file -------------------------------------
  puts
  say_status  "Model", "Adding search support into the models...", :yellow

  inject_into_file "app/models/#{class_name}.rb", after: %r|\s*class #{model_name} < ApplicationRecord$| do
    <<-CODE

    searchkick
    CODE
  end



  # ---------------------------------- make require changes in controller file -----------------------------------
  say_status  "Controller", "Adding controller action, route, and HTML for searching...", :yellow

  inject_into_file "app/controllers/#{class_name_pluralize}_controller.rb", before: %r|^\s*def index$| do
    <<-CODE

    def search
      @#{class_name_pluralize} = 
        if params[:q].present?
          #{model_name}.search(params[:q])
        else
          #{model_name}.all
        end

      render action: :index
    end

    CODE
  end


  # ---------------------------------- make require changes in view file -----------------------------------------
  inject_into_file "app/views/#{class_name_pluralize}/index.html.erb", after: %r{<h1>.*#{model_name.pluralize}</h1>}i do
    <<-CODE

   <hr>
   <%= form_tag search_#{class_name_pluralize}_path, method: 'get' do %>
     <%= label_tag :query %>
     <%= text_field_tag :q, params[:q] %>
     <%= submit_tag :search %>
   <% end %>
   <hr>
   CODE
  end

  # ------------------------------------------- add route for search method --------------------------------------------
  gsub_file 'config/routes.rb', %r{resources :#{class_name_pluralize}$}, <<-CODE
    resources :#{class_name_pluralize} do
      collection { get :search }
    end
  CODE


  # ---------------------------------- create index for models ----------------------------
  run  "rails runner '#{model_name}.reindex'"

end
