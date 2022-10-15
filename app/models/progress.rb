class Progress < ApplicationRecord
    belongs_to :user_status
    has_one :question
    has_many :candidates
    has_many :solutions, through: :candidates
    has_many :answers
    has_one :prepared_solution
end
