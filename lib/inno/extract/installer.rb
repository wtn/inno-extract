module Inno
  module Extract
    class Installer
      attr_reader :path

      def initialize(path)
        @path = path
        raise InvalidInstallerError, "File not found: #{path}" unless File.exist?(path)

        validate!
      end

      def version
        @version ||= detect_version
      end

      def payload_offset
        @payload_offset ||= find_zlb_offset
      end

      def payload_header
        @payload_header ||= read_at(payload_offset, 4)
      end

      def payload_data
        @payload_data ||= begin
          # Skip the 4-byte "zlb\x1A" header
          data = read_at(payload_offset + 4, file_size - payload_offset - 4)
          data
        end
      end

      # Detect if payload contains an embedded PE (MZ header) or raw LZMA data
      def embedded_pe?
        @embedded_pe ||= payload_data[0, 2] == "MZ"
      end

      def manifest
        @manifest ||= Manifest.new(manifest_stream)
      end

      def zlib_streams
        @zlib_streams ||= find_zlib_streams
      end

      def extract_to(output_dir)
        raise UnsupportedVersionError, "LZMA format not yet supported" unless embedded_pe?

        FileUtils.mkdir_p(output_dir)

        manifest_entries = manifest.files
        file_streams = extract_file_streams

        manifest_entries.each_with_index do |entry, idx|
          stream_data = file_streams[idx]
          next unless stream_data && entry[:install_path]

          file_path = File.join(output_dir, entry[:install_path].tr("\\", "/"))
          FileUtils.mkdir_p(File.dirname(file_path))
          File.binwrite(file_path, stream_data)
        end
      end

      private

      def validate!
        unless File.binread(path, 2) == "MZ"
          raise InvalidInstallerError, "Not a valid PE executable"
        end

        unless inno_setup_installer?
          raise InvalidInstallerError, "Not an Inno Setup installer"
        end
      end

      def inno_setup_installer?
        data = File.binread(path)
        data.include?(INNO_SETUP_SIGNATURE)
      end

      def detect_version
        data = File.binread(path)
        match = data.match(/Inno Setup Setup Data \((\d+\.\d+\.\d+)\)/)
        raise UnsupportedVersionError, "Could not detect Inno Setup version" unless match

        match[1]
      end

      def find_zlb_offset
        data = File.binread(path)
        offset = data.index(ZLB_HEADER)
        raise InvalidInstallerError, "Could not find zlb payload" unless offset

        offset
      end

      def read_at(offset, length)
        File.open(path, "rb") do |f|
          f.seek(offset)
          f.read(length)
        end
      end

      def file_size
        @file_size ||= File.size(path)
      end

      def manifest_stream
        stream = zlib_streams.first
        raise UnsupportedVersionError, "LZMA format not yet supported (no zlib manifest found)" unless stream

        stream
      end

      # Extract file streams in order matching manifest entries
      def extract_file_streams
        data = payload_data
        entries = manifest.files
        streams = []

        # Find all zlib streams and their decompressed sizes
        stream_info = find_all_streams_with_sizes(data)

        # Skip the manifest stream (first one with CSV header)
        file_streams = stream_info.reject { |s| s[:data].include?("FileKey") }

        # Match streams to entries by expected file size
        entries.each do |entry|
          expected_size = entry[:file_size]
          next unless expected_size

          # Find matching stream by decompressed size
          match = file_streams.find { |s| s[:size] == expected_size }
          if match
            streams << match[:data]
            file_streams.delete(match)
          else
            streams << nil
          end
        end

        streams
      end

      def find_all_streams_with_sizes(data)
        streams = []
        pos = 0
        max_stream_size = 30 * 1024 * 1024 # 30MB max per stream

        while pos < data.bytesize - 2
          byte1 = data.getbyte(pos)
          byte2 = data.getbyte(pos + 1)

          if zlib_header?(byte1, byte2)
            decompressed = try_decompress(data, pos, max_stream_size)
            if decompressed && decompressed.bytesize > 100
              streams << {
                offset: pos,
                size: decompressed.bytesize,
                data: decompressed,
              }
            end
          end

          pos += 1
        end

        streams
      end

      def find_zlib_streams
        streams = []
        data = payload_data
        pos = 0
        max_stream_size = 30 * 1024 * 1024 # 30MB max per stream

        while pos < data.bytesize - 2
          byte1 = data.getbyte(pos)
          byte2 = data.getbyte(pos + 1)

          if zlib_header?(byte1, byte2)
            decompressed = try_decompress(data, pos, max_stream_size)
            if decompressed && decompressed.bytesize > 1000
              streams << decompressed
            end
          end

          pos += 1
        end

        streams
      end

      def zlib_header?(byte1, byte2)
        ZLIB_HEADERS.any? { |h| h[0] == byte1 && h[1] == byte2 }
      end

      def try_decompress(data, offset, max_size)
        chunk = data.byteslice(offset, max_size)
        return nil unless chunk

        zstream = Zlib::Inflate.new
        result = zstream.inflate(chunk)
        zstream.finish
        result
      rescue Zlib::Error, Zlib::DataError, Zlib::BufError
        nil
      ensure
        zstream&.close
      end
    end
  end
end
