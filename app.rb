
require "bundler/inline"

gemfile do
  gem "prawn"
  gem "psych"
end
require "yaml"

Prawn::Fonts::AFM.hide_m17n_warning = true

module MathPractice
  class Operation
    def initialize(left:, right:, operation:, result:)
      @left = left
      @right = right
      @operation = operation
      @result = result
    end

    attr_reader :left, :right, :operation, :result
  end

  class Addition
    def initialize(left:, right:, count:)
      @left = Array(left)
      @right = Array(right)
      @count = count
    end

    def operations
      @count.times.map do |i|
        left = @left.sample
        right = @right.sample
        Operation.new(
          left:,
          right:,
          operation: "+",
          result: left + right
        )
      end
    end
  end

  class Subtraction
    def initialize(left:, right:, count:, allow_negative_result: false)
      @left = Array(left)
      @right = Array(right)
      @count = count
      @allow_negative_result = allow_negative_result
    end

    def operations
      @count.times.map do
        success = false
        left = nil
        right = nil
        100.times do
          left = @left.sample
          right = @right.sample
          if @allow_negative_result || left > right
            success = true
            break
          end
        end

        if !success
          raise "Software bug: failed to create a Subtraction exercise with a non-negative result after 100 tries"
        end

        Operation.new(
          left:,
          right:,
          operation: "-",
          result: left - right
        )
      end
    end
  end

  class Multiplication
    def initialize(left:, right:, count:)
      @left = Array(left)
      @right = Array(right)
      @count = count
    end

    def operations
      @count.times.map do |i|
        left = @left.sample
        right = @right.sample
        Operation.new(
          left:,
          right:,
          operation: "×", # This should be Win-Ansi 1252, not UTF-8
          result: left * right
        )
      end
    end
  end

  class Division
    def initialize(quotient:, divisor:, count:)
      @quotient = Array(quotient)
      @divisor = Array(divisor)
      @count = count
    end

    def operations
      @count.times.map do
        right = @divisor.sample
        result = @quotient.sample
        Operation.new(
          left: result * right,
          right:,
          operation: "÷",
          result:,
        )
      end
    end
  end

  class AnswerKey
    def initialize(worksheets)
      @worksheets = worksheets
    end

    def into_pdf(pdf)
      pdf.text("Answer Key", size: 30)
      box_w = pdf.bounds.width / 3
      op_h = 15
      problems_per_row = Worksheet::PROBLEMS_PER_ROW
      max_rows = @worksheets.map { |ws| (ws.operations.size / problems_per_row.to_f).ceil }.max
      box_h = ((max_rows + 1) * op_h)
      op_width = 30
      @worksheets.each_slice(3) do |ws_slice|
        pdf.move_down 10
        box_y = pdf.cursor
        ws_slice.each_with_index do |ws, ws_idx|
          pdf.bounding_box([(ws_idx * box_w), box_y], height: box_h, width: box_w) do
            pdf.text("#{ws.student_name} / #{ws.id}", style: :bold)
            pdf.move_down 10

            ws.operations.each_slice(problems_per_row).each_with_index do |slice, slice_idx|
              slice_y = pdf.cursor
              slice.each_with_index do |op, op_idx|
                pdf.draw_text(op.result.to_s, at: [(op_idx * op_width), slice_y])
              end
              pdf.move_down op_h
            end
          end
        end
      end
    end
  end

  class Worksheet
    PROBLEMS_PER_ROW = 5
    def self.from_config(filepath)
      data = YAML.safe_load(File.read(filepath), aliases: true)
      outfile_name = data.delete("pdf_filename") || raise(ArgumentError, "config is missing pdf_filename: ...")
      all_ws = []
      data.each do |student_name, worksheet_configs|
        worksheet_configs.each do |(sheet_name, problem_set_configs)|
          if sheet_name == "defaults"
            next
          end
          problem_sets = problem_set_configs.map do |ps_conf|
            if (count = ps_conf.delete("divide"))
              Division.new(count:, quotient: ps_param(ps_conf, "quotient"), divisor: ps_param(ps_conf, "divisor"))
            elsif (count = ps_conf.delete("add"))
              Addition.new(count:, left: ps_param(ps_conf, "left"), right: ps_param(ps_conf, "right"))
            elsif (count = ps_conf.delete("subtract"))
              Subtraction.new(count:, left: ps_param(ps_conf, "left"), right: ps_param(ps_conf, "right"), allow_negative_result: ps_param(ps_conf, "allow_negative_result", false))
            elsif (count = ps_conf.delete("multiply"))
              Multiplication.new(count:, left: ps_param(ps_conf, "left"), right: ps_param(ps_conf, "right"))
            else
              raise ArgumentError, "Unhandled worksheet config: #{ps_conf.inspect}"
            end
          end
          all_ws << self.new(student_name:, problem_sets:, id: sheet_name)
        end
      end

      key = AnswerKey.new(all_ws)
      dir = File.dirname(filepath)
      outfile = "#{dir}/#{outfile_name}"
      Prawn::Document.generate(outfile) do |pdf|
        key.into_pdf(pdf)
        all_ws.each do |ws|
          pdf.start_new_page
          ws.into_pdf(pdf)
        end
      end
      outfile
    end

    class << self
      private
      def ps_param(config, name, default = nil)
        str = config.delete(name)
        if str.nil?
          if default != nil
            default
          else
            raise ArgumentError, "Missing config #{name.inspect} in #{config.inspect}"
          end
        elsif str.is_a?(Numeric)
          str
        elsif str.include?("..")
          r_start, r_end = str.split("..").map(&:to_i)
          r_start..r_end
        elsif str =~ /^\d+$/
          str.to_i
        elsif str.nil? && default != nil
          default
        else
          raise ArgumentError, "Unrecognized config for #{name.inspect} => #{str.inspect}"
        end
      end
    end

    def initialize(problem_sets:, student_name:, id:)
      @problem_sets = problem_sets
      @operations = nil
      @student_name = student_name
      @id = id
    end

    attr_reader :student_name, :id

    def operations
      @operations ||= begin
        ops = []
        @problem_sets.each do |ps|
          ops.concat(ps.operations)
        end
        ops.shuffle!
        ops
      end
    end

    def to_pdf(filename: "worksheet.pdf")
      Prawn::Document.generate(filename) do |pdf|
        into_pdf(pdf)
      end
    end

    def into_pdf(pdf)
      starting_h = pdf.cursor
      total_width = pdf.bounds.width
      details_box_width = 200
      details_box_x = total_width - details_box_width
      details_box_h = 35

      header_box_width = total_width - details_box_width

      pdf.bounding_box([0, starting_h], width: header_box_width, height: details_box_h) do
        pdf.text('Math Practice', valign: :bottom, size: 30)
      end

      pdf.bounding_box([details_box_x, starting_h], width: details_box_width, height: details_box_h) do
        pdf.font_size(12)
        line_offset = 11
        line_1_start = pdf.cursor
        line_1_h = line_1_start - line_offset
        line_x_1 = 40
        line_x_2 = 200
        if @id
          pdf.text(@id, align: :right, color: "999999", size: 10)
        end
        pdf.move_cursor_to(line_1_start)
        pdf.text("Name: #{@student_name}")
        pdf.line([line_x_1, line_1_h], [line_x_2, line_1_h])
        pdf.stroke
        pdf.move_down 5

        line_4_h = pdf.cursor - line_offset
        pdf.text("Score:")
        pdf.line([line_x_1, line_4_h], [line_x_2, line_4_h])
        pdf.stroke
      end

      pdf.move_down(40)
      pdf.font_size(18)
      problems_per_row = PROBLEMS_PER_ROW
      width_per_problem = 50
      space_for_problems = total_width - (problems_per_row * width_per_problem)
      horizontal_margin = space_for_problems / (problems_per_row - 1)

      height_per_row = 40
      vertical_margin = 100
      total_height = pdf.bounds.height
      total_possible_rows = ((total_height - height_per_row).to_f / (height_per_row + vertical_margin)).floor + 1
      num_rows = (operations.size / problems_per_row.to_f).ceil
      if num_rows > total_possible_rows
        raise "Too many problems to render (room for #{total_possible_rows} rows, worksheet has #{num_rows} rows with #{problems_per_row} problems each (#{operations.size} total problems))"
      end

      operations.each_slice(problems_per_row).each_with_index do |group, group_idx|
        group_height = pdf.cursor
        box_y = group_height - (group_idx > 0 ? vertical_margin : 0)
        group.each_with_index do |operation, idx|
          box_x = (width_per_problem * idx) + (idx * horizontal_margin)
          pdf.bounding_box([box_x, box_y], width: width_per_problem, height: height_per_row) do
            # pdf.stroke_bounds
            pdf.text(operation.left.to_s, align: :right)
            op_height = pdf.cursor
            pdf.text(operation.operation.to_s, align: :left)
            pdf.move_cursor_to(op_height)
            pdf.text(operation.right.to_s, align: :right)
            pdf.line([0, pdf.cursor], [width_per_problem, pdf.cursor])
            pdf.stroke
          end
        end
      end
    end
  end
end


if (path = ARGV[0])
  puts "Creating practice sheets from #{path}"

  output_path = MathPractice::Worksheet.from_config(path)
  puts "Created #{output_path}"
end
