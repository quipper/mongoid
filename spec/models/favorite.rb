class Favorite
  include Mongoid::Document

  field :title
  field :count, :type => Integer, :default => 0

  embedded_in :perp, :inverse_of => :favorites

  validates_uniqueness_of :title, :case_sensitive => false

  before_save do
    self.count += 1
  end
end
