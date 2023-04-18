# Requirements:
# -------------
#
# * Git
# * Ruby  >= 2.7.0
# * Rails >= 7

# =========================================== Execute This Template =================================================
# rails app:template LOCATION=templates/ransack_search.rb



# =========================================== Rails application Settings ============================================
# ============================================= Add gems into Gemfile ==============================================

say_status  "Rubygems", "Adding ransack library into Gemfile...\n", :yellow

gem_list = `gem list`.lines
gem 'ransack' if gem_list.grep(/^ransack/)

# ==================================================================================================================





# ================================================= Install GEM ===================================================

puts
say_status  "Rubygems", "Installing Rubygems...", :yellow

run "bundle install"

# ==================================================================================================================





# ================================ Add ransack integration into the interface ===============================
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
    \n
    def self.ransackable_attributes(auth_object = nil)
      #{model_name.constantize.column_names.reject {|column| column =~ /id|created_at/i }}
    end
    CODE
  end


  # ---------------------------------- make require changes in controller file -----------------------------------
  say_status  "Controller", "Adding controller action, route, and HTML for searching...", :yellow

  inject_into_file "app/controllers/#{class_name_pluralize}_controller.rb", after: %r|^\s*class #{model_name_pluralize}Controller < ApplicationController$| do
    <<-CODE

      before_action :set_ransack_object, only: [ :index ]

    CODE
  end


  inject_into_file "app/controllers/#{class_name_pluralize}_controller.rb", after: %r|^\s*private$| do
    <<-CODE

    def set_ransack_object
      @ransack_object = #{model_name}.ransack(params[:q])
    end

    CODE
  end

  gsub_file "app/controllers/#{class_name_pluralize}_controller.rb", %r{@#{class_name_pluralize} = #{model_name}.all}, <<-CODE
  @#{class_name_pluralize} = @ransack_object.result
  CODE

  
  # ---------------------------------- make require changes in view file -----------------------------------------
  inject_into_file "app/views/#{class_name_pluralize}/index.html.erb", after: %r{<h1>.*#{model_name.pluralize}</h1>}i do
    <<-CODE

    <hr>
    <%= search_form_for @ransack_object do |f| %>
      <%= f.text_field :title_cont %>
      <%= f.submit :search %>
    <% end %>
    <hr>
   CODE
  end
end
