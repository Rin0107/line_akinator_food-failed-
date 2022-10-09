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
        registering: handle_registering,
        confirming: handle_confirming
    }

    def handle_message(event, user_id)
        if event.message['text'] == "終了"
            # 途中終了するときの処理
            message = simple_text("今回は終了しました。また遊ぶときは「はじめる」と打ってね！")
            reply_content(event, message)
            user_status = get_user_status(user_id)
            reset_status(user_status)
        else
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

    # 次の質問を選択する（ベクトルの内積を使うやつのはず）
    # progressはUserStatusのレコード
    # 返り値は、q_score_tableのfeature.valueが最小のQuestionインスタンス
    def select_next_question(progress)
        related_question_set = Set.new()
        # set型とは、重複した値を格納できない点や、
        # 添え字やキーなどの概念がなく、ユニークな要素である点、
        # 要素の順序を保持しない点などの特徴がある。
        progress.candidates.each do |s|
            # progressはCandidatesクラス（中間テーブル）と関連づいている
            q_set = s.features.each{|f| [f.question_id]}
            # Solutionモデルのfeaturesレコードを順番にfに代入して、Featuresのquestion_idをq_setに代入
            # つまり、候補群の持つfeaturesを導くquestionのidをリスト型でq_setに代入
            related_question_set.add(q_set)
            # set型のrelated_questionにq_setを代入すると、重複するqustion_idをまとめてset型にできる
        end

        q_score_table = related_question_set.to_a.each{|q_id| {q_id: 0.0}}
        # candidatesのfeaturesを導くquestion_id（重複なし）をリスト型にして、キーとして繰り返し代入し、valueは0.0としておく
        progress.candidates.each do |s|
            q_score_table.each do |q_id|
                feature = Feature.find_by(question_id: q_id, solution_id: s.id)
                # 絞り込んだquestion_idと候補群のsolution_idでFeatureインスタンスを取得し代入。これをprogress.candidatesとq_score_tableでループ回す
                if feature.present?
                    q_score_table[q_id] += feature.value
                else
                    q_score_table[q_id] += 0.0
                end
                # q_score_tableのそれぞれのvalueにfeature.valueを足す
                # これで候補群のfeatureを導くquesitonsのidをキーに持ち、
                # valueにはsolution_idとquestion_idが一致するfeature.valueを足し続ける。
                # 1.0（ハイ）と-1.0（イイエ）が混在するquestion（valueが0.0に近い）ということは、その質問の回答によって選択肢が多く絞り込まれる。
            end
        end
        q_score_table = q_score_table.each{|key, value| {key: abs(value)}}
        # q_score_tableのvalueを絶対値に。valueが大きい→その質問に対して選択肢は似た回答を持つ→その質問をしてもあまり絞り込めない、となる連想配列が完成
        p ("[select_next_question] q_score_table=> ", q_score_table)
        next_q_id = q_score_table.min{|x, y| x[1] <=> y[1]}
        # 最も絶対値が小さいquestionということは、その質問の回答が分かれる→その質問の回答によって選択肢が多く絞り込まれる。
        # rubyのmin,maxは、hashの場合、x=>[key,value], y=>[key,value] hash.eachだと、|x, y|と書くと、x=>key, y=>valueなのに…
        return Question.find(next_q_id)
        # Questionインスタンスのキーが、next_q_idに合致する行を取得。（プライマリーキーであるidで照合しているっぽい？）
    end

    # UserStatusを更新してsave
    def save_status(user_status, new_status=nil, next_question=nil)
        if new_status
            # new_statusが存在する場合
            user_status.update(status: new_status)
        if next_question
            # next_questionが存在する場合
            user_status.progress.latest_question.update(question_id: next_question.id)
        end
    end

    # UserStatusのstatusをリセットする
    def reset_status(user_status)
        user_status.progress.answers.destroy_all
        # Answerテーブルのprogress_idレコードがUserのprogress.idと合致するAnswerテーブルの行を削除
        # つまり、今回のUserのAnswerを全て削除
        user_status.progress.destroy
        # UserStatusのprogressを削除
        # つまり、今回のUserの経過状況を全て削除
        save_status(user_status, 'pending')
        # 上記を削除したUserStatusをsave
    end

    # 現の選択肢のスコアテーブル、引数はUserStatusのprogress
    # 返り値はvalueが小さい順の連想配列s_score_table
    def gen_solution_score_table(progress)
        s_score_table = progress.candidates.each{|s| {s.id: 0.0}}
        # solutionのスコアテーブルとして、Progressのcandidatesレコード（Solutionの行になる？）を繰り返しsに代入して、Solutionのidをキーに。
        # valueは全て0.0（select_next_questionと同じ手法）
        s_score_table.each do |s_id|
            progress.answers.each do |ans|
                # progressと関連付くanswersを繰り返しansに代入
                feature = Feature.find_by(question_id: ans.question_id, solution_id: s_id)
                # Featureのquestion_idがAnswerのquestion_id（回答した質問のid）と合致して、
                # Featureのsolution_idがSolutionのidと合致する一つを取得して、featureに代入
                if feature.present?
                    s_score_table[s_id] += ans.value * feature.value
                else
                    s_score_table[s_id] += ans.value * 0.0
                end
                # s_score_tableのs_id（s.id）のvalueに、ans.value（回答のvalue）×用意してあるFeatureのvalueの積を足す。（0.0 + 1.0 or -1.0)
                # 回答のvalueと用意してあるFeatureのvalueが一致していれば、1.0、一致しなければ-1.0がs_score_tableのvalueとなる
            end
        end
        s_score_table = s_score_table.sort{|x, y| x[1]<=>y[1]}.to_h
        # s_score_tableをvalueで昇順に並び替えて、ハッシュに戻す
        p ("s_score_table: ", s_score_table)
        return s_score_table
    end

    # 候補群の平均以上の候補のみを取得、引数はs_score_table、返り値はSolutionインスタンスたち
    def update_candidates(s_score_table)
        score_mean = s_score_table.values.sum(0.0) / s_score_table.values.length
        # s_score_tableのvaluesを取得し合計と要素数から、平均値を取得
        s_score_table.each do |s_id, score|
            if score >= score_mean
                return Solution.find(s_id)
                # s_score_tableのscoreがscore_mean以上の場合、そのs_idのSolutionの行を取得
            end
        end
    end

    # 決定可能か判断、引数はs_score_table, old_s_score_table、返り値はboolen
    def can_decide(s_score_table, old_s_score_table)
        scores = s_score_table.values
        # s_score_tableのvaluesを取得し（この時点で配列化されている）、scoresに代入
        return scores.length == 1 or scores[0] != scores[1] or s_score_table.keys == old_s_score_table.keys
        # scoresのlengthが1又は、scores[0]がscores[1]と異なる場合（つまり選択肢が一つの場合）又は、
        # s_score_tableのキーたちとold_s_score_tableのキーたちが一致する場合（つまりupdate_candidateしても選択肢が変わらない場合）はtrueを返す
    end

    # AnswerをProgress、セッションにpush、引数はprogress, answer_msg
    def push_answer(progress, answer_msg)
        answer = Answer.create()
        # Answerをcreateしてanswerに代入
        answer.question = progress.latest_question
        # progress.latest_questionを、createしたanwerに関連づいたquestionに代入
        # ?railsのアソシエーションメソッドを用いる必要があるかも？
        if answer_msg == "はい"
            # answer_msgが"はい"の場合、Answerのvalueに1.0を代入、
            answer.value = 1.0
        else
            # それ以外の場合-1.0を代入
            answer.value = -1.0
        end
        progress.answers << answer
        # progressのanswersにcreateしたanswerを追加する（answerにprogress_idが入る）
        # ProgressのanswersにAnswer(answer.question, answer.value)を追加（Progressのanswersにはidだけが入るのか？）
        session[:answer] = answer
    end

    # s_score_tableから、現在最もAnswerとFeatureが近いSolutionを取得、引数はs_score_table、返り値はSolutionインスタンス
    def guess_solution(s_score_table)
        return Solution.find(s_score_table.max{|x, y| x[1] <=> y[1]})
        # s_score_tableのvalueが最大値のs.idを取得し、該当のSolutionの行を取得
    end

    # 正解の場合等に呼び出されるメソッド。正解の選択肢が見つかった場合、今回の回答は全てその正解の選択肢のfeatureと考えられる。
    # なので、今回の質問と回答が正解の選択肢のQuestion_id,Feature_valueとして保持されている場合は更新し、保持されていない場合は新規作成する。 
    def update_features(progress, true_solution=nil)
        if true_solution.present?
            # true_solutionがfalse,nil以外の場合
            solution = true_solution
        else
            # true_solutionがfalse,nilの場合
            solution = guess_solution(gen_solution_score_table(progress))
            # 正解した時点のs_score_tableの最も可能性の高いSolutionインスタンス（正解）をsolutionに代入
        end

        qid_feature_table = solution.features.each{|f| {f.question_id: f}}
        # 正解のsolutionのfeaturesをfに繰り返し代入し、キー：そのquestion_id、value：そのvalueとした連想配列をqid_feature_tableに代入
        progress.answer.each do |ans|
            # progressのanswersを繰り返しansに代入し、
            if qid_feature_table.key?(ans.question_id)
                # もし、ansのquestion_idがqid_feature_tableに含まれていれば
                # （つまり、正解のsolutionのfeaturesを導いた質問の中に、これまでの回答が含まれている場合）
                feature = qid_feature_table[ans.question_id]
                # キーがans.question_idであるqid_featuer_tableのvalueをfeatureに代入
                # （つまり、正解のFeatureのvalueを回答のvalueに更新するために、
                # これまでの回答の中の一つの質問とQuestionのidが一致する、正解のsolutionのfeature.valueをfeatureに代入）
            else
                # それ以外の場合（つまり、正解のsolutionのfeaturesを導いた質問の中に、これまでの回答が含まれていない場合）
                # つまり、どこかのタイミングで新しくできた質問を今回答え、新しくできた質問に対応するfeature.valueが今回の正解の選択肢になかった場合
                feature = Feature.create()
                # Featureをcreateして
                feature.question_id = ans.question_id
                # これまでの回答のQuestion.idを新しいFeature.question_idに代入
                feature.solution_id = solution.id
                # true_solution?又は、現在のs_score_tableの最も可能性の高いSolutionインスタンスのidを新しいFeature.solution_idに代入
                feature.value = ans.value
                # これまでの回答のvalueをFeature.valueに代入
            end
            session[:feature] = feature
        end
    end

    def simple_text(text)
        reply_content = {
            type: 'text'
            text: text
        }
        return reply_content
    end

    def set_confirm_template(question_message)
        reply_content = {
            type: 'template',
            altText: "「はい」か「いいえ」をタップ。",
            template: {
              type: 'confirm',
              text: question_message + "\n途中で終わる場合は「終了」と打って！",
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
        }
        return reply_content
    end

    # GameStatusがPendingの場合akinator_handlerで呼び出されるメソッド、引数はUserStatus, message、返り値は配列[(text, items)]
    def handle_pending(user_status, message)
        if message == "はじめる"
            user_status.progress = Progress.create()
            # Progressをcreateして、UserStatusのprogressに代入
            user_status.progress.candidates = Solution.all()
            # Solutionの行を全て取得し（選択肢を全て取得）、UserStatusのprogressのcandidatesに代入
            question = select_next_question(user_status.progress)
            # 上で定義したselect_next_questionメソッド（返り値はq_score_tableのfeature.valueが最小のQuestionインスタンス）を呼び出しquestionに代入
            save_status(user_status, 'asking', question)
            # 上で定義したsave_statusメソッドを呼び出す（引数は、UserStatusインスタンス, GameState, Questionインスタンス）
            # ?'asking'で指定できるのか？番号の必要あり？
            reply_content = set_confirm_template(question.message)
            # ser_confirm_templateでquestion.messageに対して「はい」「いいえ」の確認テンプレートを作成、返り値はreply_content={}
        else
            reply_content = set_butten_template(altText: "今日何食べる？", title: "「はじめる」をタップ！", text: "はじめる")
            # set_butten_templateでtitleのvalueをテキストに、textのvalueをボタンにする。
        end
        return reply_content  
    end

    # GameStatusがAskingの場合akinator_handlerで呼び出されるメソッド、引数はUserStatus, message、返り値はreply_content
    def handle_asking(user_status, message)
        if ["はい", "いいえ"].include?(message)
            # ["はい", "いいえ"]がmessageに含まれる場合
            push_answer(user_status.progress, message)
            # UserStatusのprogressとmessageを引数に、AnswerをProgress、セッションにpush
            old_s_score_table = gen_solution_score_table(user_status.progress)
            # 現在のs_score_tableをold_s_score_tableに代入
            # これで、ProgressのAnswerが変わり、現在のスコアを古いものとして代入したので、s_score_tableを変更する準備が整った
            user_status.progress.candidates = update_candidates(old_s_score_table)
            # update_candidatesメソッドでSolution.valueの平均以上の選択肢を取得し、Progressのcandidatesが更新された
            user_status.progress.candidates.each do |c|
                p ("candidate=> id: #{c.id}, name: #{c.name}")
                # ?候補：id:, name:""でプリント
            end
            s_score_table = gen_solution_score_table(user_status.progress)
            # Progressのcandidatesが更新された状態の現在のs_score_tableをs_score_tableに代入
            if can_decide(s_score_table, old_s_score_table).blank?
                # s_score_tableとold_s_score_tableを比較したりして、選択肢が変わった場合（返り値がtrueで無い場合）
                question = select_next_question(user_status.progress)
                save_status(user_status, next_question=question)
                reply_content = set_confirm_template(question.message)
                # ser_confirm_templateでquestion.messageに対して「はい」「いいえ」の確認テンプレートを作成、返り値はreply_content={}
            else
                # 選択肢が変わらなかった場合（返り値がtrueの場合）
                most_likely_solution = guess_solution(s_score_table)
                # 現在のs_score_tanleを引数に、最もAnswersとFeatureが近いSolutionを取得して代入
                question_message = "思い浮かべているのは\n\n" + most_likely_solution.name + "\n\nですか?"
                save_status(user_status, 'guessing')
                # GameStateをGuessingにして、save_status
                reply_content = set_confirm_template(question_message)
                # ser_confirm_templateでquestion_messageに対して「はい」「いいえ」の確認テンプレートを作成、返り値はreply_content={}
            end
        else
            # ["はい", "いいえ"]がmessageに含まれない場合
            question = select_next_question(user_status.progress)
            reply_content = set_confirm_template("「はい」か「いいえ」で答えてね！\n#{question.message}")
        return reply_content
    end

    # handle_askingで選択肢が変わらなかった場合にGameStateがGuessingとなり呼び出されるメソッド
    # 引数はUserStatus, message、返り値はreply_content
    def handle_guessing(user_status, message)
        if message == "はい"
            # most_likely_solutionが当たった場合
            reply_content = simple_text("じゃあ、それ食べに行こう！")
            update_features(user_status.progress)
            # 正解の選択肢が見つかったので、その選択肢のFeature.valueを今回の回答に更新し、新しくQuestionとFeatureがあった場合は新規作成
            reset_status(user_status)
            # 今回のAnswerとUserStatusのprogressを全て削除
        elsif message == "いいえ"
            # most_likely_solutionが当たった場合
            reply_content = set_confirm_template("ありゃ、ごめんなさい！続けて質問していいですか？")
            save_status(user_status, 'resuming')
            # UserStatusは変わらないが、GameStateをGUESSINGからRESUMINGに更新
        else
            # ["はい", "いいえ"]がmessageに含まれない場合
            reply_content = set_confirm_template("「はい」か「いいえ」で教えて下さい！\n続けて質問していいですか？")
        end
        return reply_content
    end

    # handle_guessingで最も可能性が高い選択肢が解答でなかった場合にGameStateがResumingになり呼び出されるメソッド
    # 引数はUserStatus, message、返り値は配列[(text, items)]
    def handle_resuming(user_status, message)
        if message == "はい"
            # 外したが、続ける場合
            user_status.progress.candidates = Solution.all()
            # UserStatusのProgressのcandidatesをSolutionのインスタンスを全てにする
            # つまり、これまでの回答で絞り込んだcandidatesを選択肢全てにする
            question = select_next_question(user_status.progress)
            reply_content = set_confirm_template(question.message)
            save_status(user_status, 'asking', question)
            # GamestateをAskingにする。next_questionもある。
        elsif message == "いいえ"
            # 外して、続けない場合
            items = user_status.progress.candidates.first(5).each{|s| [s.name]}
            # reply_content用にitemsを用意。中身はこれまでで絞り込んだcandidatesを順に5個まで
            reply_content = simple_text("じゃあ、以下の中に食べたいものがあったらその名前を打って教えて下さい！\n#{items.join("\n")}")
            save_status(user_status, 'begging')
            # user_status.statusをbeggingに更新
        else
            # ["はい", "いいえ"]がmessageに含まれない場合
            reply_content = set_confirm_template("「はい」か「いいえ」で教えて下さい！\n続けて質問していい？")
        end
        return reply_content
    end

    # handle_resumingで続けない場合、candidatesと、"どれも当てはまらない"を提示して、GameStateがBeggingになり呼び出されるメソッド
    # 引数はUserStatusとmessage、返り値は配列[(text, items)]
    def handle_begging(user_status, message)
        if Solution.all().each{|s| [s.name]}.include?(message)
            # candidatesと"どれも当てはまらない"への返信がSolution全ての中の一つに当てはまるかを繰り返しチェックし、存在する場合
            true_solution = Solution.find_by(name: message)
            # messsage(教えてもらったSolutionのname)とSolution.nameが一致する最初の一つを本当の解答として代入
            update_features(user_status.progress, true_solution)
            # 教えてもらった本当の解答を引数に、本当の解答のFeature.valueを今回の回答に更新し、新しくQuestionとFeatureがあった場合は新規作成
            reset_status(user_status)
            # 今回のAnswerとUserStatusのprogressを全て削除
            save_status(user_status, 'pending')
            # GameStateをPendingに更新
            reply_content = simple_text("教えてくれてありがとう、じゃあそれ食べに行こう！")
        else
            # 当てはまらなかった場合
            save_status(user_status, 'registering')
            # user_status.statusをregisteringに変更
            reply_content = set_butten_template(
                altText: "ごめんなさい。。。",
                title: "分かりませんでした…。食べたいものがあったら打って教えて下さい。\n無ければ「終了」を押してね…。",
                text: "終了"
            )
        end
        return reply_content
    end

    # handle_beggingで"どれも当てはまらない"の場合、"答えを入力してくださいな…"を提示し、GameStateがRegisteringになり呼び出されるメソッド
    # 引数はUserStatusとmessage、返り値は配列[(text, items)]
    def handle_registering(user_status, message)
        prepared_solution = PreparedSolution.create()
        # preparedSolutionをcreateして代入
        # カラムはid, progress_id, name
        prepared_solution.name = message
        # message（教えてもらった答え）をnameとして代入
        user_status.progress.prepared_solution = prepared_solution
        # UserStatesのProgressのprepared_solutionに代入
        # これでprepared_solutionとprogressが関連づいた？
        save_status(user_status, 'confirming')
        # user_status.statusをconfirmingに更新
        reply_content = set_confirm_template("思い浮かべていたのは\n\n#{mesasge}\n\nでいいですか？")
        return reply_content
    end

    # handle_registeringで教えてもらった答えをprepared_solutionとして代入して、提示して、GameStateがConfirmingになり呼び出されるメソッド
    def handle_confirming(user_status, message)
        pre_solution = user_status.progress.prepared_solution
        # 教えてもらった答えをpre_solutionに代入
        name = pre_solution.name
        # 教えてもらった答えのnameをnameに代入しておく
        if message == "はい"
            # handle_registeringで提示したset_confirm_templateの「はい」を押下した場合
            pre_solution.destroy
            # pre_solutionをテーブルから削除
            new_solution = Solution.create()
            # Solutionをnewして代入
            new_solution.name = name
            # newしたSolutionのnameに、教えてもらった答えのnameを代入
            update_features(user_status.progress, new_solution)
            # new_solutionのFeature.valueを更新して、新しくQuestionとFeatureがあった場合は新規作成
            reply_content = simple_text("#{name}ですね、覚えておきます。ありがとうございました！")
            save_status(user_status, 'pending')
            # user_status.statusをpendingに更新
            reset_status(user_status)
            # 今回のAnswerとUserStatusのprogressを全て削除
        elsif message == "いいえ"
            # handle_registeringで提示したQuickMessageFormに対して"いいえ"の場合
            dpre_solution.destroy
            # pre_solutionをテーブルから削除
            save_status(user_status, 'registering')
            # user_status.statusをregisteringに更新
            reply_content = simple_text("ありゃ、もう一度食べたいものを教えて下さい")
        else
            # それ以外のmessageが来た場合
            reply_content = set_confirm_template("思い浮かべていたのは\n\n#{mesasge}\n\nでいいですか？")
            # GameStateは更新せず、同じことを繰り返す
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