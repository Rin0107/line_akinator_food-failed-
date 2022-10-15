class Question < ApplicationRecord
    has_one :latest_question
    belongs_to :progress, through: :latest_question
    has_many :features
    has_many :answers
end
