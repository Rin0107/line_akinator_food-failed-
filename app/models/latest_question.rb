class LatestQuestion < ApplicationRecord
    belongs_to :progress
    belongs_to :question
end
