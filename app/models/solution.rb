class Solution < ApplicationRecord
    has_many :features
    has_many :candidates
    has_many :progresses, through: :candidates
    has_many :features
end
