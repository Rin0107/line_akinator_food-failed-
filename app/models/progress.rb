class Progress < ApplicationRecord
    belongs_to :user_status
    has_one :latest_question
    has_one :question, through: :latest_question
    has_many :candidates
    has_many :solutions, through: :candidates
    has_many :answers
    has_one :prepared_solution
end
