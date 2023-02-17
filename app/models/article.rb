
class Article < ApplicationRecord
  validates :title, :content, :published_on, presence: true
end
