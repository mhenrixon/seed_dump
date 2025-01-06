# frozen_string_literal: true

require "action_text"
require "active_storage"

class SeedDumpling
  # Provides methods for dumping database records into Ruby code that can be used
  # as seeds. Handles various data types and supports both create and import formats.
  module DumpMethods # rubocop:disable Metrics/ModuleLength
    extend ActiveSupport::Concern

    include Enumeration

    class_methods do
      def dump(...)
        new.dump(...)
      end
    end

    def dump(records, options = {})
      return nil if records.none?

      io = prepare_io(options)
      write_records(records, io, options)
    ensure
      io&.close
    end

    private

    def dump_record(record, options) # rubocop:disable Metrics/AbcSize
      attributes = filter_attributes(record.attributes, options[:exclude])

      # Make sure we include attachments and rich text in the final output
      attributes["avatar"] = record.avatar if record.respond_to?(:avatar) && defined?(ActiveStorage::Attached::One)

      attributes["photos"] = record.photos if record.respond_to?(:photos) && defined?(ActiveStorage::Attached::Many)

      attributes["content"] = record.content if record.respond_to?(:content) && record.content.is_a?(ActionText::RichText)

      formatted_attributes = format_attributes(attributes, options[:import])
      wrap_attributes(formatted_attributes, options[:import])
    end

    def filter_attributes(attributes, exclude)
      attributes.select do |key, _|
        (key.is_a?(String) || key.is_a?(Symbol)) && exclude.exclude?(key.to_sym)
      end
    end

    def format_attributes(attributes, import_format)
      attributes.map do |attribute, value|
        import_format ? value_to_s(value) : "#{attribute}: #{value_to_s(value)}"
      end.join(", ")
    end

    def wrap_attributes(attribute_string, import_format)
      open_char, close_char = import_format ? ["[", "]"] : ["{", "}"]
      "#{open_char}#{attribute_string}#{close_char}"
    end

    def value_to_s(value) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
      formatted_value = case value
                        when BigDecimal, IPAddr, ->(v) { rgeo_instance?(v) }
                          value.to_s
                        when Date, Time, DateTime
                          value.to_fs(:db)
                        when Range
                          range_to_string(value)
                        when ->(v) { defined?(ActiveStorage::Attached::One) && v.is_a?(ActiveStorage::Attached::One) }
                          handle_active_storage_one(value)
                        when ->(v) { defined?(ActiveStorage::Attached::Many) && v.is_a?(ActiveStorage::Attached::Many) }
                          handle_active_storage_many(value)
                        when ->(v) { defined?(ActionText::RichText) && v.is_a?(ActionText::RichText) }
                          handle_rich_text(value)
                        else
                          value
      end
      formatted_value.inspect
    end

    def range_to_string(range)
      from = infinite_value?(range.begin) ? "" : range.begin
      to   = infinite_value?(range.end) ? "" : range.end
      exclude_end = range.exclude_end? ? ")" : "]"
      "[#{from},#{to}#{exclude_end}"
    end

    def rgeo_instance?(value)
      value.class.ancestors.any? { |ancestor| ancestor.to_s == "RGeo::Feature::Instance" }
    end

    def infinite_value?(value)
      value.respond_to?(:infinite?) && value.infinite?
    end

    def prepare_io(options)
      if options[:file].present?
        mode = options[:append] ? "a+" : "w+"
        File.open(options[:file], mode)
      else
        StringIO.new
      end
    end

    def write_records(records, io, options) # rubocop:disable Metrics/MethodLength
      options[:exclude] ||= %i[id created_at updated_at]

      method_call = build_method_call(records, options)
      io.write(method_call)
      io.write("[\n  ")

      enumeration_method = select_enumeration_method(records)
      send(enumeration_method, records, options) do |record_strings, last_batch|
        io.write(record_strings.join(",\n  "))
        io.write(",\n  ") unless last_batch
      end

      io.write("\n]#{format_import_options(options)})\n")

      return if options[:file].present?

      io.rewind
      io.read
    end

    def build_method_call(records, options)
      method = options[:import] ? "import" : "create!"
      model_name = determine_model(records)
      if options[:import]
        attributes_list = attribute_names(records, options).map { _1.to_sym.inspect }.join(", ")
        "#{model_name}.#{method}([#{attributes_list}], "
      else
        "#{model_name}.#{method}("
      end
    end

    def format_import_options(options)
      return "" unless options[:import].is_a?(Hash)

      options_string = options[:import].map { |key, value| "#{key}: #{value}" }.join(", ")
      ", #{options_string}"
    end

    def attribute_names(records, options)
      attributes = records.respond_to?(:attribute_names) ? records.attribute_names : records.first.attribute_names
      attributes.reject { |name| options[:exclude].include?(name.to_sym) }
    end

    def determine_model(records)
      if records.is_a?(Class)
        records
      elsif records.respond_to?(:model)
        records.model
      else
        records.first.class
      end
    end

    def select_enumeration_method(records)
      if records.is_a?(ActiveRecord::Relation) || records.is_a?(Class)
        :active_record_enumeration
      else
        :enumerable_enumeration
      end
    end

    def handle_active_storage_one(attachment)
      return nil unless attachment.attached?

      copy_attachment_to_seeds_dir(attachment)

      {
        io: "File.open(Rails.root.join('db/seeds/files', '#{attachment.filename}'))",
        filename: attachment.filename.to_s,
        content_type: attachment.blob.content_type,
      }
    end

    def handle_active_storage_many(attachments)
      return [] unless attachments.attached?

      attachments.map do |attachment|
        copy_attachment_to_seeds_dir(attachment)

        {
          io: "File.open(Rails.root.join('db/seeds/files', '#{attachment.filename}'))",
          filename: attachment.filename.to_s,
          content_type: attachment.blob.content_type,
        }
      end
    end

    def copy_attachment_to_seeds_dir(attachment) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      return unless attachment&.blob

      seeds_dir = Rails.root.join("db/seeds/files")
      FileUtils.mkdir_p(seeds_dir)

      target_path = seeds_dir.join(attachment.filename.to_s)

      # Skip if file already exists
      return if File.exist?(target_path)

      begin
        # Try to get direct file path first
        source_path = attachment.blob.service.path_for(attachment.blob.key)
        if source_path && File.exist?(source_path)
          FileUtils.cp(source_path, target_path)
        else
          # Fallback to downloading for cloud storage
          File.open(target_path, "wb") do |file|
            attachment.download { |chunk| file.write(chunk) }
          end
        end
      rescue StandardError => e
        Rails.logger.error "Failed to copy attachment #{attachment.filename}: #{e.message}"
        raise e
      end
    end

    def handle_rich_text(rich_text)
      rich_text.body&.to_html
    end
  end
end
