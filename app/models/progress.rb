class Progress < ApplicationRecord
    belongs_to :user_status
    has_many :latest_questions
    has_many :questions, through: :latest_questions
end
