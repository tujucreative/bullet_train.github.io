require "test_helper"
require "stringio"

class CLITest < Minitest::Test
  def test_returns_block_value
    assert_equal 3, DocsSite::CLI.run(err: StringIO.new) { 3 }
  end

  def test_build_error_exits_1_with_message
    err = StringIO.new
    exit_error = assert_raises(SystemExit) { DocsSite::CLI.run(err: err) { raise DocsSite::BuildError, "boom" } }
    assert_equal 1, exit_error.status
    assert_equal "boom\n", err.string
  end

  def test_other_errors_propagate
    assert_raises(ArgumentError) { DocsSite::CLI.run(err: StringIO.new) { raise ArgumentError } }
  end

  def test_build_reports_page_count
    config = DocsSite::Config.new(out_dir: "/out", env: {})
    out = StringIO.new
    DocsSite::CLI.build(config, builder: Struct.new(:build).new(57), out: out)
    assert_equal "Built 57 pages into /out\n", out.string
  end

  def test_build_error_from_builder_exits_1
    builder = Object.new
    def builder.build = raise(DocsSite::BuildError, "nope")
    err = StringIO.new
    exit_error = assert_raises(SystemExit) { DocsSite::CLI.build(DocsSite::Config.new(env: {}), builder: builder, out: StringIO.new, err: err) }
    assert_equal 1, exit_error.status
    assert_equal "nope\n", err.string
  end
end
