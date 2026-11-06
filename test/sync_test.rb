require "test_helper"
require "tmpdir"
require "fileutils"
require "stringio"

class SyncTest < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir("sync-test")
    @source = File.join(@tmp, "src")
    @upstream = File.join(@tmp, "upstream")
    FileUtils.mkdir_p(File.join(@source, "docs"))
    File.write(File.join(@source, "docs", "a.md"), "A")
    File.write(File.join(@source, "docs", "b.md"), "B")
    FileUtils.cp(File.join(DocsSite::ROOT, "src", "menu.yml"), File.join(@source, "menu.yml"))

    FileUtils.mkdir_p(File.join(@upstream, "bullet_train", "docs"))
    FileUtils.mkdir_p(File.join(@upstream, "bullet_train", "app", "views", "layouts"))
    File.write(File.join(@upstream, "bullet_train", "docs", "b.md"), "B2")
    File.write(File.join(@upstream, "bullet_train", "docs", "c.md"), "C")
    File.write(File.join(@upstream, "bullet_train", "app", "views", "layouts", "docs.html.erb"), "url: '/docs/teams'")

    @config = DocsSite::Config.new(source_dir: @source, env: {})
    @out = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def sync
    DocsSite::Sync.new(config: @config, out: @out).call(upstream_dir: @upstream, ref: "v9", sha: "abc")
  end

  def test_replaces_docs_and_reports
    result = sync
    assert_equal({added: ["c.md"], removed: ["a.md"], changed: ["b.md"]}, result)
    refute File.exist?(File.join(@source, "docs", "a.md"))
    assert_equal "B2", File.read(File.join(@source, "docs", "b.md"))
    assert_equal "C", File.read(File.join(@source, "docs", "c.md"))
  end

  def test_writes_upstream_file
    sync
    text = File.read(File.join(@source, "UPSTREAM"))
    assert_includes text, "repo: https://github.com/bullet-train-co/bullet_train-core"
    assert_includes text, "ref: v9"
    assert_includes text, "sha: abc"
    assert_match(/^synced: \d{4}-\d{2}-\d{2}$/, text)
  end

  def test_warns_on_menu_drift
    sync
    assert_includes @out.string, "WARNING: menu differs from upstream layout"
    assert_includes @out.string, "only in menu.yml"
    assert_includes @out.string, "only in upstream"
  end
end
