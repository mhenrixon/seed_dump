# frozen_string_literal: true

require "spec_helper"

describe SeedDumpling::DumpMethods do
  def expected_output(include_id: false, id_offset: 0)
    output = "Sample.create!([\n  "

    data = ((1 + id_offset)..(3 + id_offset)).map do |i|
      "{#{include_id ? "id: #{i}, " : ''}string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}"
    end

    "#{output}#{data.join(",\n  ")}\n])\n"
  end

  def dump(...)
    SeedDumpling.dump(...)
  end

  describe ".dump" do
    before do
      Rails.application.eager_load!

      create_db

      create_list(:sample, 3)
    end

    context "without file option" do
      it "returns the dump of the models passed in" do
        expect(dump(Sample)).to eq(expected_output)
      end
    end

    context "with file option" do
      let!(:filename) { Tempfile.new(File.join(Dir.tmpdir, "foo"), nil) }

      after do
        File.unlink(filename)
      end

      it "dumps the models to the specified file" do
        dump(Sample, file: filename)

        File.open(filename) { |file| expect(file.read).to eq(expected_output) }
      end

      context "with append option" do
        it "appends to the file rather than overwriting it" do
          dump(Sample, file: filename)
          dump(Sample, file: filename, append: true)

          File.open(filename) { |file| expect(file.read).to eq(expected_output + expected_output) }
        end
      end
    end

    context "when value is am ActiveRecord::Relation" do
      it "returns nil if the count is 0" do
        expect(dump(EmptyModel)).to be_nil
      end

      context "with an order parameter" do
        it "dumps the models in the specified order" do
          Sample.delete_all
          3.times { |i| create(:sample, integer: i) }

          expect(dump(Sample.order("integer DESC"))).to eq("Sample.create!([\n  {string: \"string\", text: \"text\", integer: 2, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {string: \"string\", text: \"text\", integer: 1, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {string: \"string\", text: \"text\", integer: 0, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n")
        end
      end

      context "without an order parameter" do
        it "dumps the models sorted by primary key ascending" do
          expect(dump(Sample)).to eq(expected_output)
        end
      end

      context "with a limit parameter" do
        it "dumps the number of models specified by the limit when the limit is smaller than the batch size" do
          expected_output = "Sample.create!([\n  {string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"

          expect(dump(Sample.limit(1))).to eq(expected_output)
        end

        it "dumps the number of models specified by the limit when the limit is larger than the batch size but not a multiple of the batch size" do
          Sample.delete_all
          create_list(:sample, 4)

          expect(dump(Sample.limit(3), batch_size: 2)).to eq(expected_output(id_offset: 3))
        end
      end
    end

    context "with a batch_size parameter" do
      it "does not raise an exception" do
        expect { dump(Sample, batch_size: 100) }.not_to raise_error
      end

      it "does not cause records to not be dumped" do
        expect(dump(Sample, batch_size: 2)).to eq(expected_output)

        expect(dump(Sample, batch_size: 1)).to eq(expected_output)
      end
    end

    context "when value is an Array" do
      it "returns the dump of the models passed in" do
        expect(dump(Sample.all.to_a, batch_size: 2)).to eq(expected_output)
      end

      it "returns nil if the array is empty" do
        expect(dump([])).to be_nil
      end
    end

    context "with an exclude parameter" do
      it "excludes the specified attributes from the dump" do
        expected_output = "Sample.create!([\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"
        actual_output = dump(Sample, exclude: %i[id created_at updated_at string float datetime])
        expect(actual_output).to eq(expected_output)
      end
    end

    context "when value is a Range" do
      it "dumps a class with ranges" do
        expected_output = "RangeSample.create!([\n  {range_with_end_included: \"[1,3]\", range_with_end_excluded: \"[1,3)\", positive_infinite_range: \"[1,]\", negative_infinite_range: \"[,1]\", infinite_range: \"[,]\"}\n])\n"

        expect(dump([RangeSample.new])).to eq(expected_output)
      end
    end

    context "when using activerecord-import" do
      it "dumps in the activerecord-import format when import is true" do
        expect(dump(Sample, import: true, exclude: [])).to eq <<~RUBY
          Sample.import([:id, :string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean, :created_at, :updated_at], [
            [1, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"],
            [2, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"],
            [3, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"]
          ])
        RUBY
      end

      it "omits excluded columns if they are specified" do
        expect(dump(Sample, import: true, exclude: %i[id created_at updated_at])).to eq <<~RUBY
          Sample.import([:string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean], [
            ["string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false],
            ["string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false],
            ["string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false]
          ])
        RUBY
      end

      context "with specified output parameters" do
        it "dumps in the activerecord-import format when import is true" do
          expect(dump(Sample, import: { validate: false }, exclude: [])).to eq <<~RUBY
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

  describe "Active Storage and Action Text handling" do
    let(:test_model) do
      Class.new(ApplicationRecord) do
        include ActiveStorage::Attached::Model
        include GlobalID::Identification

        self.table_name = "test_models"
        has_one_attached :avatar
        has_many_attached :photos
        has_rich_text :content

        def self.name
          "TestModel"
        end

        def self.primary_key
          "id"
        end

        def to_trix_content_attachment_partial_path
          "rich_text_area"
        end
      end
    end

    before do
      ActiveRecord::Base.connection.create_table :test_models do |t|
        t.string :name
        t.timestamps
      end

      # Load and run the Active Storage migration
      require "active_storage/engine"
      migration_dir = Gem.loaded_specs["activestorage"].full_gem_path

      require File.join(migration_dir, "db/migrate/20170806125915_create_active_storage_tables.rb")
      CreateActiveStorageTables.new.change

      # Load and run the Action Text migration
      require "action_text/engine"
      migration_dir = Gem.loaded_specs["actiontext"].full_gem_path

      require File.join(migration_dir, "db/migrate/20180528164100_create_action_text_tables.rb")
      CreateActionTextTables.new.change

      Object.const_set(:TestModel, test_model)

      FileUtils.rm_rf(Rails.root.join("db/seeds/files"))
    end

    after do
      # Delete in correct order to avoid foreign key violations
      %i[
        active_storage_attachments
        active_storage_variant_records
        active_storage_blobs
        test_models
        action_text_rich_texts
      ].each do |table_name|
        if ActiveRecord::Base.connection.table_exists?(table_name)
          ActiveRecord::Base.connection.execute("DELETE FROM #{table_name}")
          ActiveRecord::Base.connection.drop_table(table_name)
        end
      end

      FileUtils.rm_rf(Rails.root.join("db/seeds/files"))
    end

    it "copies single attachments to seeds directory" do
      model = test_model.create!(name: "Test")

      file_path = fixture_file("icon.png")
      model.avatar.attach(io: file_path, filename: "icon.png", content_type: "image/png")

      dump([model])

      expect(Rails.root.join("db/seeds/files/icon.png").exist?).to be true
      expect(FileUtils.identical?(file_path, Rails.root.join("db/seeds/files/icon.png"))).to be true
    end

    it "copies multiple attachments to seeds directory" do
      model = test_model.create!(name: "Test")

      2.times do |i|
        # Get a fresh file handle for each attachment
        file = fixture_file("icon.png")
        model.photos.attach(
          io: file,
          filename: "icon#{i}.png",
          content_type: "image/png",
        )
        file.close
      end

      dump([model])

      2.times do |i|
        expect(Rails.root.join("db/seeds/files", "icon#{i}.png").exist?).to be true
        expect(FileUtils.identical?(
          fixture_file("icon.png"),
          Rails.root.join("db/seeds/files", "icon#{i}.png"),
        ),
              ).to be true
      end
    end

    it "doesn't copy the same file twice" do
      model = test_model.create!(name: "Test")

      file = fixture_file("icon.png")
      model.avatar.attach(
        io: file,
        filename: "icon.png",
        content_type: "image/png",
      )
      file.close

      allow(FileUtils).to receive(:cp).and_call_original

      dump([model])
      expect(FileUtils).to have_received(:cp).once

      dump([model]) # Second dump shouldn't copy the file again
      expect(FileUtils).to have_received(:cp).once
    end

    it "handles rich text content" do
      model = test_model.create!(name: "Test")
      model.reload

      model.content = "<div>Test rich text content</div>"

      result = dump([model])
      expect(result).to include("<div>Test rich text content</div>")
    end

    it "handles nil attachments" do
      model = test_model.create!(name: "Test")
      model.reload

      result = dump([model])

      expect(result).to include("avatar: nil")
      expect(result).to include("photos: []")
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
