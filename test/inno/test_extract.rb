require "test_helper"

class Inno::TestExtract < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Inno::Extract::VERSION
  end
end

# Tests for basic installer parsing (works with both embedded PE and LZMA formats)
class Inno::Extract::TestInstaller < Minitest::Test
  def setup
    @fixture_path = File.expand_path("../../tmp/innosetup-6.3.3.exe", __dir__)
    skip "Fixture not found (run bin/setup): #{@fixture_path}" unless File.exist?(@fixture_path)
    @installer = Inno::Extract::Installer.new(@fixture_path)
  end

  def test_detects_inno_setup_version
    assert_equal "6.3.0", @installer.version
  end

  def test_finds_zlb_payload_offset
    assert @installer.payload_offset > 0
    assert @installer.payload_offset < File.size(@fixture_path)
  end

  def test_reads_payload_header
    assert_equal "zlb\x1A".b, @installer.payload_header
  end

  def test_detects_payload_format
    # Official Inno Setup installer uses LZMA (no embedded PE)
    refute @installer.embedded_pe?, "Expected LZMA format (no embedded PE)"
  end
end

# Tests for embedded PE format extraction (Bloomberg-style installers)
# Set INNO_FIXTURE_PE env var to path of an installer with embedded PE payload
class Inno::Extract::TestEmbeddedPE < Minitest::Test
  def setup
    @fixture_path = ENV["INNO_FIXTURE_PE"]
    skip "INNO_FIXTURE_PE not set" unless @fixture_path
    skip "Fixture not found: #{@fixture_path}" unless File.exist?(@fixture_path)
    @installer = Inno::Extract::Installer.new(@fixture_path)
    skip "Fixture is not embedded PE format" unless @installer.embedded_pe?
  end

  def test_detects_embedded_pe_format
    assert @installer.embedded_pe?, "Expected embedded PE format"
  end

  def test_extracts_manifest
    manifest = @installer.manifest
    refute_nil manifest
    assert manifest.files.any?, "Expected manifest to have files"
  end

  def test_manifest_contains_file_entries
    manifest = @installer.manifest
    first_file = manifest.files.first
    refute_nil first_file[:install_path]
    refute_nil first_file[:file_hash]
    refute_nil first_file[:file_size]
  end
end

class Inno::Extract::TestExtraction < Minitest::Test
  def setup
    @fixture_path = ENV["INNO_FIXTURE_PE"]
    skip "INNO_FIXTURE_PE not set" unless @fixture_path
    skip "Fixture not found: #{@fixture_path}" unless File.exist?(@fixture_path)
    @installer = Inno::Extract::Installer.new(@fixture_path)
    skip "Fixture is not embedded PE format" unless @installer.embedded_pe?
    @output_dir = Dir.mktmpdir("inno_extract_test")
  end

  def teardown
    FileUtils.rm_rf(@output_dir) if @output_dir && File.exist?(@output_dir)
  end

  def test_extracts_files_to_directory
    @installer.extract_to(@output_dir)
    extracted_files = Dir.glob(File.join(@output_dir, "**", "*")).select { |f| File.file?(f) }
    assert extracted_files.any?, "Expected at least one file to be extracted"
  end

  def test_extracted_files_match_manifest_hashes
    @installer.extract_to(@output_dir)
    manifest = @installer.manifest

    manifest.files.first(3).each do |entry|
      file_path = File.join(@output_dir, entry[:install_path].tr("\\", "/"))
      next unless File.exist?(file_path)

      actual_hash = Digest::SHA256.hexdigest(File.binread(file_path))
      assert_equal entry[:file_hash], actual_hash, "Hash mismatch for #{entry[:install_path]}"
    end
  end
end
