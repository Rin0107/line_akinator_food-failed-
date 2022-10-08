class AkinatorController < ApplicationController
    protect_from_forgery except: [:food]

    def reply_content(event, messages)
        res = client.reply_message(
          event['replyToken'],
          messages
        )
        logger.warn res.read_body unless Net::HTTPOK === res
        res
      end

    def food
        body = request.body.read
        # POSTリクエストは引数として受け取っており、request変数に入っている
        # POSTリクエスト(リクエスト行、ヘッダー、空白行、メッセージボディ)

        signature = request.env['HTTP_X_LINE_SIGNATURE']
        unless client.validate_signature(body, signature)
            return head :bad_request
        end
        # 署名を検証

        events = client.parse_events_from(body)
        # メッセージのtype,userId,message等の情報を連想配列でeventsに代入（json形式から連想配列にしている）

        events.each do |event|

            user_id = event.source['userId']
            # eventのsourceからuseridを取得し、user_idに代入
            profile = client.get_profile(user_id)
            # clientのget_profileメソッドの引数にuser_idを代入、このままだとjson形式の文？
            profile = JSON.parse(profile.read_body)
            # json形式のresponseを連想配列に変換
            p "Receives message:#{message} from #{profile['displayName']}."

            case event
                when Line::Bot::Event::Message
                    handle_message(event, user_id)
            end
        end
        head :ok
    end

    akinator_handler_table = {
        pending: handle_pending,
        asking: handle_asking,
        guessing: handle_guessing,
        resuming: handle_resuming,
        begging: handle_begging
    }

    def handle_message(event, user_id)
        case event.type
        when Line::Bot::Event::MessageType::Text
            message = event.message['text']
            # 受け取ったメッセージの文字列をmessageに代入
            user_status = get_user_status(user_id)
            # UserStatusのインスタンスを引数user_idで照合して、存在しなかった場合作成して、返り値はUserStatusインスタンス
            status = user_status.status
            # UserStatusを作成した時、user_status.statusは'pending'
            akinator_handler = akinator_handler_table.get(status)
            # status（'pending'）を引数に、akinator_handler_tableからvalue（メソッド）を取得し、代入
            reply_content = akinator_handler(user_status, message)
            # akinator_handler（メソッド）に引数user_status, messageを渡し、返り値は連想配列{}
            reply_content(event, reply_content)
            # reply_contentメソッドを呼び出し
            # Messaging APIでは各メッセージに応答トークンという識別子がある
            # reply_messageの引数はreplyTokenとtype:textのtext:内容
        else
            
        end
        
    end

    private
        def client
            @client ||= Line::Bot::Client.new { |config|
                config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
                config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
              }
        end
end
