# Requirements:
# -------------
#
# * Git
# * Ruby  >= 2.7.0
# * Rails >= 7

# =========================================== Execute This Template =================================================
# rails app:template LOCATION=templates/pg_search.rb



# =========================================== Rails application Settings ============================================
# ============================================= Add gems into Gemfile ==============================================

say_status  "Rubygems", "Adding pg_search library into Gemfile...\n", :yellow

gem_list = `gem list`.lines
gem 'pg_search' if gem_list.grep(/^pg_search/)

# ==================================================================================================================





# ================================================= Install GEM ===================================================

puts
say_status  "Rubygems", "Installing Rubygems...", :yellow

run "bundle install"

# ==================================================================================================================





# ================================ Add pg_search integration into the interface ===============================
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

    include PgSearch::Model
    pg_search_scope :search, against: [:title, :content, :published_on]
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
end
