class Question < ApplicationRecord
    has_many :latest_questions
    has_many :progresses, through: :latest_questions
end
