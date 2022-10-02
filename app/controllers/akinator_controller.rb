class AkinatorController < ApplicationController
    protect_from_forgery except: [:food]

    def convert_form_to_message(form_list):
        # ?引数として受け取るform_listを一つずつ取り出し、formのカラムを取り出し、TextSendMessageに引数として渡してインスタンスを作成して配列に追加
        # 返り値は配列[(TextSendMessage)]
        reply_content = []
        for form in form_list:
            if isinstance(form, TextMessageForm):
                # formのデータ型がTextMessageFormのデータ型と一致している場合（handle_askingのelse等）
                message = TextSendMessage(text=form.text)
                # ?TextSendMessageの引数textにformのtextを代入して渡し、messageに代入
            elsif isinstance(form, QuickMessageForm):
                # formのデータ型がQuickMessageFormのデータ型と一致している場合（handle_pending等）
                items = [QuickReplyButton(action=MessageAction(label=item, text=item)) for item in form.items]
                # ?formのitemsを繰り返しitemに代入し、MessageActionの引数label, textにitemを代入して、QuickReplyButtonの引数actionに代入して、
                # itemsに上記を代入
                message = TextSendMessage(text=form.text, quick_reply=QuickReply(items=items))
            reply_content.append(message)
        return reply_content

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
            case event
                when Line::Bot::Event::Message
                    case event.type
                        when Line::Bot::Event::MessageType::Text
                            message = event.message['text']
                            # 受け取ったメッセージの文字列をmessageに代入
                            user_id = event.source['userId']
                            # eventのsourceからuseridを取得し、user_idに代入
                            response = client.get_profile(user_id)
                            # clientのget_profileメソッドの引数にuser_idを代入、このままだとjson形式の文？
                            case response
                                when Net::HTTPSuccess
                                contact = JSON.parse(response.body)
                                # json形式のresponseを連想配列に変換
                                p "Receives message:#{message} from #{contact['displayName']}."
                            end
                            
                            user_status = get_user_status(user_id)
                            # UserStatusのインスタンスを引数user_idで照合して、存在しなかった場合作成して、返り値はUserStatusインスタンス
                            status = user_status.status
                            # UserStatusを作成した時、user_status.statusは'pending'
                            akinator_handler = akinator_handler_table.get(status)
                            # status（'pending'）を引数に、akinator_handler_tableからvalue（メソッド）を取得し、代入
                            reply_content = akinator_handler(user_status, message)
                            # akinator_handler（メソッド）に引数user_status, messageを渡し、返り値は配列[(text, items)]
                            reply_content = convert_form_to_message(reply_content)
                            # reply_content = 配列[(TextSendMessage)]
                            client.reply_message(event['replyToken'], reply_content)
                            # Messaging APIでは各メッセージに応答トークンという識別子がある
                            # reply_messageの引数はreplyTokenとtype:textのtext:内容
                    end
            end
        end
        head :ok
    end

    private
        def client
            @client ||= Line::Bot::Client.new { |config|
                config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
                config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
              }
        end
end
