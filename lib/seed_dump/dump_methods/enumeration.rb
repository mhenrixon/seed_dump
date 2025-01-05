# frozen_string_literal: true

class SeedDump
  module DumpMethods
    module Enumeration
      def active_record_enumeration(records, _io, options)
        # Ensure records are ordered by primary key if not already ordered
        unless records.respond_to?(:arel) && records.arel.orders.present?
          records = records.order("#{records.quoted_table_name}.#{records.quoted_primary_key} ASC")
        end

        num_of_batches, batch_size, last_batch_size = batch_params_from(records, options)

        # Iterate over each batch
        (1..num_of_batches).each do |batch_number|
          last_batch = (batch_number == num_of_batches)
          current_batch_size = last_batch ? last_batch_size : batch_size

          # Fetch and process records for the current batch
          record_strings = records
            .offset((batch_number - 1) * batch_size)
            .limit(current_batch_size)
            .map { |record| dump_record(record, options) }

          yield record_strings, last_batch
        end
      end

      def enumerable_enumeration(records, _io, options)
        _, batch_size = batch_params_from(records, options)
        record_strings = []

        records.each_with_index do |record, index|
          record_strings << dump_record(record, options)
          last_batch = (index == records.size - 1)

          if record_strings.size == batch_size || last_batch
            yield record_strings, last_batch
            record_strings = []
          end
        end
      end

      def batch_params_from(records, options)
        batch_size = batch_size_from(options)
        total_count = records.count

        num_of_batches = (total_count.to_f / batch_size).ceil
        remainder = total_count % batch_size
        last_batch_size = remainder.zero? ? batch_size : remainder

        [num_of_batches, batch_size, last_batch_size]
      end

      def batch_size_from(options)
        options[:batch_size]&.to_i || 1000
      end
    end
  end
end
