# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

case ENV["SECTION"]
    when "foods"
        add_solutions = [
            "すし"
        ]
    when "1"
        add_questions = [
            "和食の気分ですか？",
            "中華もあり？"
        ]
        add_features_matrix = [
            [1.0, -1.0]
        ]
end

if add_solutions.present?
    add_solutions.each do |s|
        solution = {name: s}
        Solution.create!(solution)
    end
end

if add_questions.present? && add_features_matrix.present?
    solutions = Solution.all

    if add_features_matrix.length == solutions.length
        # 最新のSolutionのレコード数とadd_features_matrixの要素数が一致する場合

        a_f_m_length_array = []
        add_features_matrix.each do |f|
            a_f_m_length_array = a_f_m_length_array.push(add_features_matrix[f].length)
            # add_features_matrixの二次元要素（？）数を配列に、add_features_matrixの一次元要素数だけ追加
        end

        if a_f_m_length_array.sum == a_f_m_length_array[0] * a_f_m_length_array.length
            # add_features_matrixの二次元要素数の総和と、add_features_matrixの最初の一次元要素の二次元要素数とadd_features_matrixの一次元要素数の積が一致する場合
            
            add_questions.each do |q|
                question = {message: q}
                Question.create!(question)
            end

            added_q = Question.last(add_questions.length)
            for q_l in 1..added_q.length do
                for s in solutions do
                    value = add_features_matrix[s.id -1][q_l -1]

                    f = Feature.create()
                    f.question = added_q[q_l -1]
                    f.solution = s
                    f.value = value
                end
            end

        else
            p "Error, add_feature_matrixのうちのどれかが、add_questionsの要素数と異なります。 add_features_matrixの二次元要素数 => #{a_f_m_length_array}"
        end

    else
        # 一致しない場合
        p "now, solutions => #{solutions.name.join(', ')}"
    end
end
