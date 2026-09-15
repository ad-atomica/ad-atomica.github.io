# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"

class ContentValidationTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def setup
    @temporary_directory = Dir.mktmpdir("ad-atomica-content-")
    %w[scripts _data _people assets/uploads].each do |path|
      FileUtils.mkdir_p(File.join(@temporary_directory, path))
    end
    FileUtils.cp(File.join(ROOT, "scripts/validate_content.rb"), File.join(@temporary_directory, "scripts"))
    FileUtils.cp_r(Dir[File.join(ROOT, "_data/*")], File.join(@temporary_directory, "_data"))
    FileUtils.cp_r(Dir[File.join(ROOT, "_people/*")], File.join(@temporary_directory, "_people"))
    FileUtils.cp_r(Dir[File.join(ROOT, "assets/uploads/*")], File.join(@temporary_directory, "assets/uploads"))
  end

  def teardown
    FileUtils.remove_entry(@temporary_directory)
  end

  def test_valid_content_passes
    assert_validation_passes
  end

  def test_duplicate_anchors_fail
    mutate_home do |home|
      home["sections"][1]["anchor"] = home["sections"][0]["anchor"]
    end
    assert_validation_fails("duplicate anchor")
  end

  def test_unknown_section_type_fails
    mutate_home do |home|
      home["sections"][0]["type"] = "free-form-html"
    end
    assert_validation_fails("unsupported section type")
  end

  def test_invalid_card_count_fails
    mutate_home do |home|
      grid = home["sections"].find { |section| section["type"] == "card-grid" }
      grid["cards"] = grid["cards"].first(1)
    end
    assert_validation_fails("must contain between 2 and 4 cards")
  end

  def test_invalid_video_id_fails
    mutate_home do |home|
      video = home["sections"].find { |section| section["type"] == "video" }
      video["youtube_id"] = "not-a-url"
    end
    assert_validation_fails("11-character YouTube video ID")
  end

  def test_duplicate_people_group_fails
    mutate_home do |home|
      team = home["sections"].find { |section| section["type"] == "people-grid" && section["group"] == "team" }.dup
      team["anchor"] = "second-team"
      home["sections"] << team
    end
    assert_validation_fails("duplicate team people grids")
  end

  def test_too_many_navigation_items_fail
    mutate_home do |home|
      home["sections"].each_with_index do |section, index|
        section["navigation_label"] = "Section #{index + 1}" if index < 6
      end
    end
    assert_validation_fails("no more than 5 body sections")
  end

  private

  def mutate_home
    path = File.join(@temporary_directory, "_data/home.yml")
    home = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
    yield home
    File.write(path, YAML.dump(home))
  end

  def validation_result
    Open3.capture3(
      RbConfig.ruby,
      File.join(@temporary_directory, "scripts/validate_content.rb"),
      chdir: @temporary_directory
    )
  end

  def assert_validation_passes
    stdout, stderr, status = validation_result
    assert status.success?, "Expected validation to pass.\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
  end

  def assert_validation_fails(message)
    stdout, stderr, status = validation_result
    refute status.success?, "Expected validation to fail.\nstdout:\n#{stdout}"
    assert_includes stderr, message
  end
end
