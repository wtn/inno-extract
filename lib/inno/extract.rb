require "zlib"
require "csv"
require "digest"
require "fileutils"

require_relative "extract/version"
require_relative "extract/installer"
require_relative "extract/manifest"

module Inno
  module Extract
    class Error < StandardError; end
    class UnsupportedVersionError < Error; end
    class InvalidInstallerError < Error; end

    INNO_SETUP_SIGNATURE = "Inno Setup Setup Data"
    ZLB_HEADER = "zlb\x1A".b
    SUPPORTED_VERSION = "6.3.0"

    ZLIB_HEADERS = [
      [0x78, 0x01], # No compression
      [0x78, 0x5E], # Fast compression
      [0x78, 0x9C], # Default compression
      [0x78, 0xDA], # Best compression
    ].freeze
  end
end
