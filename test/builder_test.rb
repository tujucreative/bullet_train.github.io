require "test_helper"
require "fileutils"
require "stringio"
require "tmpdir"

class BuilderTest < Minitest::Test
  STUB_CSS = ->(path) {
    File.write(path, "/*css*/")
    true
  }

  def setup
    @tmp_dirs = []
  end

  def teardown
    @tmp_dirs.each { |dir| FileUtils.rm_rf(dir) }
  end

  def tmpdir
    Dir.mktmpdir.tap { |dir| @tmp_dirs << dir }
  end

  def build(base_path: "/bullet_train.github.io", source_dir: nil, css_command: STUB_CSS)
    out_dir = tmpdir
    config = DocsSite::Config.new(base_path: base_path, out_dir: out_dir, source_dir: source_dir, env: {})
    count = DocsSite::Builder.new(config: config, css_command: css_command, out: StringIO.new).build
    [out_dir, count, config]
  end

  def built
    @built ||= build
  end

  def read(path)
    File.read(File.join(built[0], path), encoding: "UTF-8")
  end

  def assert_built(path, out_dir = built[0])
    assert File.exist?(File.join(out_dir, path)), "expected #{path} to be built"
  end

  def test_builds_all_pages
    out_dir, count, config = built
    assert_equal Dir[File.join(config.docs_dir, "**/*.md")].size, count
    assert_equal 57, count
    %w[docs/index.html docs/getting-started/index.html docs/billing/stripe/index.html docs/webhooks/incoming/index.html].each do |path|
      assert_built path, out_dir
    end
  end

  def test_root_files
    assert_includes read("index.html"), "url=/bullet_train.github.io/docs/"
    assert_built "404.html"
    assert_built ".nojekyll"
  end

  def test_assets_copied
    %w[logo/logo.png upgrade-images/1-find-action.png assets/menu.js assets/site.css assets/themify/themify-icons.css assets/themify/themify-icons.woff].each do |path|
      assert_built path
    end
  end

  def test_links_rewritten
    assert_includes read("docs/upgrades/index.html"), 'src="/bullet_train.github.io/upgrade-images/1-find-action.png"'
    assert_includes read("docs/webhooks/outgoing/index.html"), 'href="/bullet_train.github.io/docs/webhooks/incoming/#security"'
  end

  def test_index_grid
    assert_includes read("docs/index.html"), "xl:grid grid-cols-3 gap-20"
  end

  def test_empty_base_path
    out_dir, = build(base_path: "")
    html = File.read(File.join(out_dir, "docs/teams/index.html"), encoding: "UTF-8")
    assert_includes html, 'href="/docs/permissions/"'
    refute_includes html, 'href="//'
  end

  def test_broken_link_fails
    tmp_src = File.join(tmpdir, "src")
    FileUtils.cp_r(File.join(DocsSite::ROOT, "src"), tmp_src)
    File.open(File.join(tmp_src, "docs/teams.md"), "a") { |file| file.write("\n[x](/docs/nope)\n") }
    error = assert_raises(DocsSite::BuildError) { build(base_path: "", source_dir: tmp_src) }
    assert_includes error.message, "Broken link in teams: /docs/nope/"
  end

  def test_missing_docs_dir_fails
    assert_raises(DocsSite::BuildError) { build(source_dir: tmpdir) }
  end

  def test_css_failure_fails
    assert_raises(DocsSite::BuildError) { build(css_command: ->(_) { false }) }
  end
end
