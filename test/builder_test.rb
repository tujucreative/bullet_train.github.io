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

  def build(base_path: "/bullet_train.github.io", source_dir: nil, css_command: STUB_CSS, out_dir: tmpdir)
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

  def test_root_relative_links_point_at_bullettrain_co
    assert_includes read("docs/heroku/index.html"), 'href="https://bullettrain.co/users/sign_up"'
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

  def copy_src
    File.join(tmpdir, "src").tap { |dir| FileUtils.cp_r(File.join(DocsSite::ROOT, "src"), dir) }
  end

  def test_broken_link_fails
    tmp_src = copy_src
    File.open(File.join(tmp_src, "docs/teams.md"), "a") { |file| file.write("\n[x](/docs/nope)\n") }
    error = assert_raises(DocsSite::BuildError) { build(base_path: "", source_dir: tmp_src) }
    assert_includes error.message, "Broken link in teams: /docs/nope/"
  end

  def test_unprefixed_link_fails
    tmp_src = copy_src
    layout = File.join(tmp_src, "layout.html.erb")
    File.write(layout, File.read(layout).sub("<main ", %(<a href="/somewhere-unprefixed">x</a><main )))
    error = assert_raises(DocsSite::BuildError) { build(source_dir: tmp_src) }
    assert_includes error.message, "Unprefixed link in teams: /somewhere-unprefixed"
  end

  def test_marker_written
    assert_built ".docs-site-build"
  end

  def test_foreign_out_dir_refused
    out_dir = tmpdir
    keep = File.join(out_dir, "keep.txt")
    File.write(keep, "mine")
    error = assert_raises(DocsSite::BuildError) { build(out_dir: out_dir) }
    assert_includes error.message, "Refusing to replace #{out_dir}: not empty and not a previous docs build"
    assert_equal "mine", File.read(keep)
  end

  def test_previous_build_replaced
    out_dir = tmpdir
    build(out_dir: out_dir)
    File.write(File.join(out_dir, "stale.txt"), "old")
    _, count = build(out_dir: out_dir)
    assert_equal 57, count
    refute File.exist?(File.join(out_dir, "stale.txt"))
    assert_built "docs/index.html", out_dir
  end

  def test_empty_existing_out_dir_ok
    out_dir = tmpdir
    assert Dir.empty?(out_dir)
    _, count = build(out_dir: out_dir)
    assert_equal 57, count
  end

  def test_out_dir_at_root_fails
    config = DocsSite::Config.new(out_dir: DocsSite::ROOT, env: {})
    assert_raises(DocsSite::BuildError) { DocsSite::Builder.new(config: config, css_command: STUB_CSS, out: StringIO.new).build }
    assert Dir.exist?(File.join(DocsSite::ROOT, "src/docs"))
  end

  def test_out_dir_equal_to_source_dir_fails
    tmp_src = copy_src
    [tmp_src, File.dirname(tmp_src)].each do |out_dir|
      config = DocsSite::Config.new(out_dir: out_dir, source_dir: tmp_src, env: {})
      assert_raises(DocsSite::BuildError) { DocsSite::Builder.new(config: config, css_command: STUB_CSS, out: StringIO.new).build }
      assert Dir.exist?(File.join(tmp_src, "docs")), "#{out_dir} must not be removed"
    end
  end

  def test_missing_docs_dir_fails
    assert_raises(DocsSite::BuildError) { build(source_dir: tmpdir) }
  end

  def test_css_failure_fails
    assert_raises(DocsSite::BuildError) { build(css_command: ->(_) { false }) }
  end
end
