require "test_helper"

class MenuTest < Minitest::Test
  UPSTREAM_DIR = ENV.fetch("BT_CORE_DIR", "/tmp/claude-0/-home-user/6d18f5f6-1718-51d2-9c0d-69ca8de42800/scratchpad/src/bullet_train-core")

  def config(base = "")
    DocsSite::Config.new(base_path: base, env: {})
  end

  def menu(base = "")
    DocsSite::Menu.load(config(base))
  end

  def items(m = menu)
    m.sections.flat_map(&:items)
  end

  def test_section_titles
    expected = ["Introduction", "General Topics", "Developer Tools", "Accounts & Teams", "User Interface", "Billing", "Integration", "Add-Ons", "Deployment"]
    assert_equal expected, menu.sections.map(&:title)
  end

  def test_first_items
    first = items.first
    assert_equal "Table of Contents", first.label
    assert_equal "/docs/", first.url
    assert_equal "index", first.slug
    assert_equal "ti ti-list", first.icon
  end

  def test_external_items
    externals = items.select(&:external)
    assert_equal ["Magic Test", "Nice Partials", "Showcase"], externals.map(&:label)
    externals.each do |item|
      assert item.url.start_with?("https://github.com/bullet-train-co/"), item.url
      assert_nil item.slug
    end
  end

  def test_internal_items_exist
    internal = items.reject(&:external)
    refute_empty internal
    internal.each do |item|
      assert File.exist?(File.join(config.docs_dir, "#{item.slug}.md")), "missing doc for #{item.slug}"
    end
  end

  def test_every_item_has_icon
    items.each { |item| assert_match(/\Ati ti-[a-z-]+\z/, item.icon, item.label) }
  end

  def test_matches_upstream_layout
    layout = File.join(UPSTREAM_DIR, "bullet_train/app/views/layouts/docs.html.erb")
    skip "upstream layout not found at #{layout}" unless File.exist?(layout)
    assert_equal DocsSite::Menu.upstream_urls(File.read(layout, encoding: "UTF-8")), menu.internal_urls
  end

  def test_upstream_urls_strips_md_and_dedupes
    erb = "url: '/docs/a.md' url: '/docs/a' url: 'https://x.test' url: '/docs'"
    assert_equal Set["/docs/a", "/docs"], DocsSite::Menu.upstream_urls(erb)
  end

  def test_active
    m = menu("/b")
    teams = items(m).find { |i| i.url == "/b/docs/teams/" }
    assert teams
    assert m.active?(teams, "/b/docs/teams/")
    refute m.active?(teams, "/b/docs/")
  end
end
