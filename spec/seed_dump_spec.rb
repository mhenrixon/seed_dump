# frozen_string_literal: true

require "spec_helper"

describe SeedDump do
  describe ".dump_using_environment" do
    before do
      create_db

      Rails.application.eager_load!

      create(:sample)

      allow(described_class).to receive(:dump).and_call_original
    end

    describe "APPEND" do
      it "specifies append as true if the APPEND env var is 'true'" do
        described_class.dump_using_environment("APPEND" => "true")

        expect(described_class).to have_received(:dump).with(anything, include(append: true))
      end

      it "specifies append as true if the APPEND env var is 'TRUE'" do
        described_class.dump_using_environment("APPEND" => "TRUE")

        expect(described_class).to have_received(:dump).with(anything, include(append: true))
      end

      it "specifies append as false the first time if the APPEND env var is not 'true' (and true after that)" do
        create(:another_sample)

        described_class.dump_using_environment("APPEND" => "false")

        expect(described_class).to have_received(:dump).with(anything, include(append: false)).ordered
        expect(described_class).to have_received(:dump).with(anything, include(append: true)).ordered
      end
    end

    describe "BATCH_SIZE" do
      it "passes along the specified batch size" do
        described_class.dump_using_environment("BATCH_SIZE" => "17")

        expect(described_class).to have_received(:dump).with(anything, include(batch_size: 17))
      end

      it "passes along a nil batch size if BATCH_SIZE is not specified" do
        described_class.dump_using_environment

        expect(described_class).to have_received(:dump).with(anything, include(batch_size: nil))
      end
    end

    describe "EXCLUDE" do
      it "passes along any attributes to be excluded" do
        described_class.dump_using_environment("EXCLUDE" => "baggins,saggins")

        expect(described_class).to have_received(:dump).with(anything, include(exclude: %i[baggins saggins]))
      end
    end

    describe "FILE" do
      it "passes the FILE parameter to the dump method correctly" do
        described_class.dump_using_environment("FILE" => "blargle")

        expect(described_class).to have_received(:dump).with(anything, include(file: "blargle"))
      end

      it "passes db/seeds.rb as the file parameter if no FILE is specified" do
        described_class.dump_using_environment

        expect(described_class).to have_received(:dump).with(anything, include(file: "db/seeds.rb"))
      end
    end

    describe "LIMIT" do
      it "applies the specified limit to the records" do
        relation_double = instance_spy(ActiveRecord::Relation)
        allow(Sample).to receive(:limit).with(5).and_return(relation_double)

        described_class.dump_using_environment("LIMIT" => "5")

        expect(described_class).to have_received(:dump).with(relation_double, anything)
      end
    end

    ["", "S"].each do |model_suffix|
      model_env = "MODEL#{model_suffix}"

      describe model_env do
        context "if #{model_env} is not specified" do
          it "dumps all non-empty models" do
            create(:another_sample)

            described_class.dump_using_environment

            [Sample, AnotherSample].each do |model|
              expect(described_class).to have_received(:dump).with(model, anything)
            end
          end
        end

        context "if #{model_env} is specified" do
          it "dumps only the specified model" do
            create(:another_sample)

            described_class.dump_using_environment(model_env => "Sample")

            expect(described_class).to have_received(:dump).with(Sample, anything)
          end

          it "does not dump empty models" do
            described_class.dump_using_environment(model_env => "EmptyModel, Sample")

            expect(described_class).not_to have_received(:dump).with(EmptyModel, anything)
          end
        end
      end
    end

    describe "MODELS_EXCLUDE" do
      it "dumps all non-empty models except the specified models" do
        create(:another_sample)

        described_class.dump_using_environment("MODELS_EXCLUDE" => "AnotherSample")

        expect(described_class).to have_received(:dump).with(Sample, anything)
      end
    end

    it "runs ok without ActiveRecord::SchemaMigration being set (needed for Rails Engines)" do
      hide_const("ActiveRecord::SchemaMigration")

      allow(described_class).to receive(:dump)

      described_class.dump_using_environment
    end
  end
end
