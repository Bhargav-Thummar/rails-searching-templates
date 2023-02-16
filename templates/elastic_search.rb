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
    
    # run 'sudo apt-get update'
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

# ----- Check for Elasticsearch Engine-------------------------------------------------------------------
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
