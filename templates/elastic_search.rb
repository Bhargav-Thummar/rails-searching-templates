# Requirements:
# -------------
#
# * Git
# * Ruby  >= 2.7.0
# * Rails >= 7
# * ElasticSearch version 7.17.9

require 'uri'
require 'net/http'
require 'json'

unless (run 'sudo service elasticsearch status | grep running')
  say_status "ERROR", "Failed to start elasticsearch service \n\n", :red

  # ------------ install if Elasticsearch is not available ---------------
  begin      
    say_status "INFO", "Installing Elastic Search...---------\n\n", :yellow
    
    run 'sudo apt-get update'
    # run 'sudo dpkg -i elasticsearch-7.17.deb'
  
    # Trying installing with APT after adding Elastic’s package source list...

    # Add the public GPG key to APT
    run 'curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -'

    # add the Elastic source list to the sources.list.d directory, where APT will search for new sources
    run 'echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list'

    # run 'sudo apt-get update'

    # Install Elasticsearch with this command
    run 'sudo apt install elasticsearch'

    # Configuring Elasticsearch
    unless (run "sudo cat /etc/elasticsearch/elasticsearch.yml | grep 'network.host: localhost'")
      # run 'sudo chmod 700 /etc/elasticsearch/elasticsearch.yml'
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

# ------------- Check if elasticsearch service is running properly -----------------

# restart the service
run 'sudo service elasticsearch enable'
run 'sudo service elasticsearch restart'

$elasticsearch_url = ENV.fetch('ELASTICSEARCH_URL', 'http://localhost:9200')

# ----- Check for Elasticsearch Engine -------------------------------------------------------------------
required_elasticsearch_version = '7'

begin
  cluster_info = Net::HTTP.get(URI.parse($elasticsearch_url))

rescue Errno::ECONNREFUSED => e
  say_status "ERROR", "Cannot connect to Elasticsearch on <#{$elasticsearch_url}>\n\n", :red
  exit(1)

rescue StandardError => e
  say_status "ERROR", "#{e.class}: #{e.message}", :red
  exit(1)
end


# ----- Add gems into Gemfile ---------------------------------------------------------------------

puts
say_status  "Rubygems", "Adding Elasticsearch libraries into Gemfile...\n", :yellow

gem_list = `gem list`.lines
gem 'elasticsearch'       unless gem_list.grep(/^elasticsearch \(.*\)/)
gem 'elasticsearch-model' unless gem_list.grep(/^elasticsearch-model \(.*\)/)
gem 'elasticsearch-rails' unless gem_list.grep(/^elasticsearch-rails \(.*\)/)

# ----- Disable asset logging in development ------------------------------------------------------

puts
say_status  "Application", "Disabling asset logging in development...\n", :yellow

environment 'config.assets.logger = false', env: 'development'

# ----- Install gems ------------------------------------------------------------------------------

puts
say_status  "Rubygems", "Installing Rubygems...", :yellow

run "bundle install"

# ----- Add Elasticsearch integration into the model ----------------------------------------------

puts
say_status  "Concern", "Adding elastic search concern", :yellow

file 'app/models/concerns/elastic_searchable.rb', <<-CODE
module ElasticSearchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks

    def self.search(query)
      __elasticsearch__.search(
        {
          query: {
            multi_match: {
              query: query
            }
          }
        }
      )
    end

    after_commit on: [:create, :update] do
      __elasticsearch__.index_document
    end
  end
end

CODE

# ------------------ Add model names for search functionality ----------------------------------
models = 
  [
    'User'
  ]

models.each do |model_name|
  class_name = model_name.underscore
  class_name_pluralize = class_name.pluralize

  puts
  say_status  "Model", "Adding search support into the models...", :yellow

  prepend_to_file "app/models/#{class_name}.rb" do 
    "require 'elasticsearch/model' \n"
  end
  
  inject_into_file "app/models/#{class_name}.rb", after: %r|\s*class #{model_name} < ApplicationRecord$| do
    <<-CODE

    include ElasticSearchable
    CODE
  end

  # ----- Add Elasticsearch integration into the interface ------------------------------------------

  puts
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

      @#{class_name_pluralize} = @#{class_name_pluralize}.records

      render action: :index
    end

    CODE
  end

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

  append_to_file "app/views/#{class_name_pluralize}/index.html.erb" do 
    "<%= link_to 'All #{model_name.pluralize}', #{class_name_pluralize}_path %>"
  end

  gsub_file 'config/routes.rb', %r{resources :#{class_name_pluralize}$}, <<-CODE
    resources :#{class_name_pluralize} do
      collection { get :search }
    end
  CODE

  run  "rails runner '#{model_name}.__elasticsearch__.create_index!'"
  run  "rails runner '#{model_name}.import'"
end
