class Question < ApplicationRecord
    belongs_to :progress
    has_many :features
    has_many :answers
end
