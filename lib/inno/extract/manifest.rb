module Inno
  module Extract
    class Manifest
      attr_reader :raw_data, :metadata, :files

      def initialize(data)
        @raw_data = data.force_encoding("UTF-8")
        @metadata = {}
        @files = []
        parse!
      end

      def product
        metadata[:product]
      end

      def component
        metadata[:component]
      end

      def version
        metadata[:version]
      end

      private

      def parse!
        lines = raw_data.lines.map(&:chomp)

        # Parse metadata comments (lines starting with ;;)
        lines.each do |line|
          if line.start_with?(";;")
            parse_metadata_line(line)
          end
        end

        # Parse CSV file entries (skip header and comments)
        csv_lines = lines.reject { |l| l.start_with?(";;") || l.strip.empty? }
        return if csv_lines.empty?

        header = csv_lines.shift
        headers = CSV.parse_line(header)

        csv_lines.each do |line|
          begin
            values = CSV.parse_line(line)
            next unless values && values.length >= headers.length

            entry = headers.zip(values).to_h
            @files << normalize_entry(entry)
          rescue CSV::MalformedCSVError
            # Skip malformed lines
          end
        end
      end

      def parse_metadata_line(line)
        # Format: ";; key = value"
        match = line.match(/^;;\s*(\S+)\s*=\s*(.+)$/)
        return unless match

        key = match[1].tr(".", "_").tr("-", "_").to_sym
        value = match[2].strip.delete_prefix('"').delete_suffix('"')
        @metadata[key] = value
      end

      def normalize_entry(entry)
        {
          file_key: entry["FileKey"],
          encoded_size: entry["EncodedSize"]&.to_i,
          encoding: entry["Encoding"],
          file_intent: entry["FileIntent"],
          options: entry["Options"],
          install_path: entry["InstallPath"],
          file_hash: entry["FileHash"],
          file_size: entry["FileSize"]&.to_i,
        }
      end
    end
  end
end
