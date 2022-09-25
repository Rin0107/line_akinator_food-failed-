class AkinatorController < ApplicationController
    protect_from_forgery except: [:food]

    def food
    end
end
