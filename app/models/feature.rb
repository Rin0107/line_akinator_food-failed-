class Feature < ApplicationRecord
    belongs_to :question
    belongs_to :solution
end
