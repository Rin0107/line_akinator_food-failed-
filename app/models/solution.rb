class Solution < ApplicationRecord
    has_many :features, dependent: :destroy
    has_many :candidates
    has_many :progresses, through: :candidates
end
