require "minitest/autorun"
require_relative "./app"

class AppTest < Minitest::Test
  include MathPractice

  def test_it_works
    ws = Worksheet.new(
      id: "f-101",
      student_name: "Frances",
      problem_sets: [
        Addition.new(
          left: 2..100,
          right: 200..300,
          count: 5,
        ),
        Subtraction.new(
          left: 2..10,
          right: 2..10,
          count: 5,
        ),
        Subtraction.new(
          left: 2..10,
          right: 2..10,
          count: 5,
          allow_negative_result: true,
        ),
        Multiplication.new(
          left: 2..10,
          right: 2..10,
          count: 5,
        ),
        Division.new(
          quotient: 1..10,
          divisor: 3..10,
          count: 3,
        )
      ]
    )

    assert_equal 23, ws.operations.size
    ws.to_pdf
  end

  def test_it_does_config
    Worksheet.from_config("./example/exercises.yml")
  end
end
