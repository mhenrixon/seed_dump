# frozen_string_literal: true

class SeedDump
  # Provides methods for dumping database records into Ruby code that can be used
  # as seeds. Handles various data types and supports both create and import formats.
  module DumpMethods
    include Enumeration

    def dump(records, options = {})
      return nil if records.none?

      io = prepare_io(options)
      write_records(records, io, options)
    ensure
      io&.close
    end

    private

    def dump_record(record, options)
      attributes = filter_attributes(record.attributes, options[:exclude])
      formatted_attributes = format_attributes(attributes, options[:import])
      wrap_attributes(formatted_attributes, options[:import])
    end

    def filter_attributes(attributes, exclude)
      attributes.select do |key, _|
        (key.is_a?(String) || key.is_a?(Symbol)) && !exclude.include?(key.to_sym)
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

    def value_to_s(value)
      formatted_value = case value
                        when BigDecimal, IPAddr, ->(v) { rgeo_instance?(v) }
                          value.to_s
                        when Date, Time, DateTime
                          value.to_formatted_s(:db)
                        when Range
                          range_to_string(value)
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

    def write_records(records, io, options)
      options[:exclude] ||= %i[id created_at updated_at]

      method_call = build_method_call(records, options)
      io.write(method_call)
      io.write("[\n  ")

      enumeration_method = select_enumeration_method(records)
      send(enumeration_method, records, io, options) do |record_strings, last_batch|
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
        attributes_list = attribute_names(records, options).map(&:to_sym).map(&:inspect).join(", ")
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
  end
end
