class AkinatorController < ApplicationController
    protect_from_forgery except: [:food]

    def reply_content(event, messages)
        rep = client.reply_message(
          event['replyToken'],
          messages
        )
        logger.warn rep.read_body unless Net::HTTPOK === rep
        rep
      end
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
        if event.message['text'] == "終了"
            # 途中終了するときの処理
            message = {
                type: 'text'
                text: "今回は終了しました。また遊ぶときは「はじめる」と打ってね！"
            }
            reply_content(event, message)
            user_status = get_user_status(user_id)
            reset_status(user_status)
        end

        case event.type
        when Line::Bot::Event::MessageType::Text
            message = event.message['text']
            # 受け取ったメッセージの文字列をmessageに代入
            user_status = get_user_status(user_id)
            # UserStatusのインスタンスを引数user_idで照合して、存在しなかった場合作成して、返り値はUserStatusインスタンス
            status = user_status.status
            # UserStatusを作成した時、user_status.statusは'pending'
            akinator_handler = akinator_handler_table.fetch(:status)
            # status（'pending'）を引数に、akinator_handler_tableからvalue（メソッド）を取得し、代入
            reply_content = akinator_handler(user_status, message)
            # akinator_handler（メソッド）に引数user_status, messageを渡し、返り値は連想配列{}
            reply_content(event, reply_content)
            # reply_contentメソッドを呼び出し
            # Messaging APIでは各メッセージに応答トークンという識別子がある
            # reply_messageの引数はreplyTokenとtype:textのtext:内容
        end
    end

    def get_user_status(user_id)
        user_stauts = UserStatus.find_by(user_id: user_id)
        # user_idを受け取り、UserStatusインスタンスを検索して、sessionに情報を保存
        if user_status.nil?
            # 照合して存在してない場合
            user_status = UserStatus.create(user_id: user_id)
            # UserStatusのstatusはモデルでカラムをenum型に定義し、defaultで0='pending'としておく
        end
        session[:user_status] = user_status
        return user_status
    end

    def set_confirm_template(question)
        text = question.message
        reply_content = {
            type: 'template',
            altText: "「はい」か「いいえ」をタップ。",
            template: {
              type: 'confirm',
              text: text + "\n途中で終わる場合は「終了」と打って下さい。",
              actions: [
                {
                  type: 'message',
                  label: "はい",
                  text: "はい"
                },
                {
                  type: 'message',
                  label: "いいえ",
                  text: "いいえ"
                }
              ]
            }
        }
        return reply_content
    end

    def set_butten_template(altText, title, text)
        reply_content = {
            type: 'template',
            altText: altText,
            template: {
                type: 'buttons',
                text: title,
                actions: [
                    {
                    type: 'message',
                    label: text,
                    text: text
                    }
                ]
            }
    end

    # GameStatusがPendingの場合akinator_handlerで呼び出されるメソッド、引数はUserStatus, message、返り値は配列[(text, items)]
    def handle_pending(user_status, message):
        if message == "はじめる":
            user_status.progress = Progress.create()
            # Progressをcreateして、UserStatusのprogressに代入
            user_status.progress.candidates = Solution.all()
            # Solutionの行を全て取得し（選択肢を全て取得）、UserStatusのprogressのcandidatesに代入
            question = select_next_question(user_status.progress)
            # 上で定義したselect_next_questionメソッド（返り値はq_score_tableのfeature.valueが最小のQuestionインスタンス）を呼び出しquestionに代入
            save_status(user_status, 'asking', question)
            # 上で定義したsave_statusメソッドを呼び出す（引数は、UserStatusインスタンス, GameState, Questionインスタンス）
            # ?'asking'で指定できるのか？番号の必要あり？
            set_confirm_template(question)
            # ser_confirm_templateでquestion.messageに対して「はい」「いいえ」の確認テンプレートを作成、返り値はreply_content={}
        else:
            set_butten_template(altText: "今日は何食べる？", title: "「はじめる」をタップ！", text: "はじめる")
            # set_butten_templateでtitleのvalueをテキストに、textのvalueをボタンにする。
        end
        return reply_content  
    end

    private
        def client
            @client ||= Line::Bot::Client.new { |config|
                config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
                config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
              }
        end
end
