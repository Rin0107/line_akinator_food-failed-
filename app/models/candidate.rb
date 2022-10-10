class Candidate < ApplicationRecord
    belongs_to :progress
    belongs_to :solution
end
