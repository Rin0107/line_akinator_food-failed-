class UserStatus < ApplicationRecord
    has_one :progresses
    enum :status, {pending: 0, asking: 1, guessing: 2, resuming: 3, begging: 4, registering: 5, confirming: 6}
end
