# frozen_string_literal: true

require "spec_helper"

describe SeedDump do
  def expected_output(include_id = false, id_offset = 0)
    output = "Sample.create!([\n  "

    data = ((1 + id_offset)..(3 + id_offset)).map do |i|
      "{#{include_id ? "id: #{i}, " : ''}string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}"
    end

    "#{output}#{data.join(",\n  ")}\n])\n"
  end

  describe ".dump" do
    before do
      Rails.application.eager_load!

      create_db

      create_list(:sample, 3)
    end

    context "without file option" do
      it "returns the dump of the models passed in" do
        expect(described_class.dump(Sample)).to eq(expected_output)
      end
    end

    context "with file option" do
      before do
        @filename = Tempfile.new(File.join(Dir.tmpdir, "foo"), nil)
      end

      after do
        File.unlink(@filename)
      end

      it "dumps the models to the specified file" do
        described_class.dump(Sample, file: @filename)

        File.open(@filename) { |file| expect(file.read).to eq(expected_output) }
      end

      context "with append option" do
        it "appends to the file rather than overwriting it" do
          described_class.dump(Sample, file: @filename)
          described_class.dump(Sample, file: @filename, append: true)

          File.open(@filename) { |file| expect(file.read).to eq(expected_output + expected_output) }
        end
      end
    end

    context "ActiveRecord relation" do
      it "returns nil if the count is 0" do
        expect(described_class.dump(EmptyModel)).to be_nil
      end

      context "with an order parameter" do
        it "dumps the models in the specified order" do
          Sample.delete_all
          3.times { |i| create(:sample, integer: i) }

          expect(described_class.dump(Sample.order("integer DESC"))).to eq("Sample.create!([\n  {string: \"string\", text: \"text\", integer: 2, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {string: \"string\", text: \"text\", integer: 1, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {string: \"string\", text: \"text\", integer: 0, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n")
        end
      end

      context "without an order parameter" do
        it "dumps the models sorted by primary key ascending" do
          expect(described_class.dump(Sample)).to eq(expected_output)
        end
      end

      context "with a limit parameter" do
        it "dumps the number of models specified by the limit when the limit is smaller than the batch size" do
          expected_output = "Sample.create!([\n  {string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"

          expect(described_class.dump(Sample.limit(1))).to eq(expected_output)
        end

        it "dumps the number of models specified by the limit when the limit is larger than the batch size but not a multiple of the batch size" do
          Sample.delete_all
          create_list(:sample, 4)

          expect(described_class.dump(Sample.limit(3), batch_size: 2)).to eq(expected_output(false, 3))
        end
      end
    end

    context "with a batch_size parameter" do
      it "does not raise an exception" do
        described_class.dump(Sample, batch_size: 100)
      end

      it "does not cause records to not be dumped" do
        expect(described_class.dump(Sample, batch_size: 2)).to eq(expected_output)

        expect(described_class.dump(Sample, batch_size: 1)).to eq(expected_output)
      end
    end

    context "Array" do
      it "returns the dump of the models passed in" do
        expect(described_class.dump(Sample.all.to_a, batch_size: 2)).to eq(expected_output)
      end

      it "returns nil if the array is empty" do
        expect(described_class.dump([])).to be_nil
      end
    end

    context "with an exclude parameter" do
      it "excludes the specified attributes from the dump" do
        expected_output = "Sample.create!([\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"
        actual_output = described_class.dump(Sample,exclude: %i[id created_at updated_at string float datetime])
        expect(actual_output).to eq(expected_output)
      end
    end

    context "Range" do
      it "dumps a class with ranges" do
        expected_output = "RangeSample.create!([\n  {range_with_end_included: \"[1,3]\", range_with_end_excluded: \"[1,3)\", positive_infinite_range: \"[1,]\", negative_infinite_range: \"[,1]\", infinite_range: \"[,]\"}\n])\n"

        expect(described_class.dump([RangeSample.new])).to eq(expected_output)
      end
    end

    context "activerecord-import" do
      it "dumps in the activerecord-import format when import is true" do
        expect(described_class.dump(Sample, import: true, exclude: [])).to eq <<~RUBY
          Sample.import([:id, :string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean, :created_at, :updated_at], [
            [1, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"],
            [2, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"],
            [3, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"]
          ])
        RUBY
      end

      it "omits excluded columns if they are specified" do
        expect(described_class.dump(Sample, import: true, exclude: %i[id created_at updated_at])).to eq <<~RUBY
          Sample.import([:string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean], [
            ["string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false],
            ["string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false],
            ["string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false]
          ])
        RUBY
      end

      context "should add the params to the output if they are specified" do
        it "dumps in the activerecord-import format when import is true" do
          expect(described_class.dump(Sample, import: { validate: false }, exclude: [])).to eq <<~RUBY
            Sample.import([:id, :string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean, :created_at, :updated_at], [
              [1, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"],
              [2, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"],
              [3, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"]
            ], validate: false)
          RUBY
        end
      end
    end
  end
end

class RangeSample
  def attributes
    {
      "range_with_end_included" => (1..3),
      "range_with_end_excluded" => (1...3),
      "positive_infinite_range" => (1..Float::INFINITY),
      "negative_infinite_range" => (-Float::INFINITY..1),
      "infinite_range" => (-Float::INFINITY..Float::INFINITY),
    }
  end
end
