class AkinatorController < ApplicationController
    protect_from_forgery except: [:food]

    def food
    end

    private
        def client
            @client ||= Line::Bot::Client.new { |config|
                config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
                config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
              }
        end
end
