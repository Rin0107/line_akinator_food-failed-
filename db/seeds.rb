# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
foods = []
questions = []
features_matrix = []

case ENV["SECTION"]
    when "0"
        solutions = [
            "すし"
        ]
    when "1"
        add_questions = [
            "和食の気分ですか？"
            "中華もあり？"
        ]
        add_features_matrix = [
            {1.0, -1.0}
        ]
end

if solutions.present?
    solutions.each do |s|
        solutions = {name: s}
        Solution.create!(s)
    end
end

if add_features_matrix?
    for i in add_features_matrix.length do
        for j in add_features_matrix[i].length do
         add_array = {integer: j+1, string: i+1, float: array2[i][j]};
         features_matrix.push(add_array);
        end
    end
    features_matrix
end
