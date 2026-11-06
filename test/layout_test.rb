require "test_helper"

class LayoutTest < Minitest::Test
  def config
    @config ||= DocsSite::Config.new(base_path: "/b", env: {})
  end

  def page
    DocsSite::Page.new(slug: "teams", html: "<h1>Teams</h1><p>Hello & bye</p>", config: config)
  end

  def output
    @output ||= DocsSite::Layout.new(config: config, menu: DocsSite::Menu.load(config)).render(page)
  end

  def doc
    @doc ||= Nokogiri::HTML5(output)
  end

  def test_document_shell
    assert output.start_with?("<!DOCTYPE html>")
    assert_includes output, "<title>Teams — Bullet Train Developer Documentation</title>"
  end

  def test_assets_prefixed
    assert_includes output, 'href="/b/assets/site.css"'
    assert_includes output, 'src="/b/assets/menu.js"'
    assert_includes output, 'href="/b/assets/themify/themify-icons.css"'
    assert_includes output, 'src="/b/logo/logo.png"'
    refute_match %r{(href|src)="/(assets|logo)/}, output
  end

  def test_content_card
    assert_includes output, 'id="bt-docs-content"'
    assert_includes output, page.html
  end

  def test_meta
    assert_equal "https://tujucreative.github.io/b/docs/teams/", doc.at_css('meta[property="og:url"]')["content"]
    assert_match(/<meta content="[^"]*Hello &amp; bye[^"]*" name="description"/, output)
  end

  def test_active_item
    assert_includes doc.at_css('a[href="/b/docs/teams/"]')["class"].split, "bg-primary-900"
    refute_includes doc.at_css('a[href="/b/docs/"]')["class"].split, "bg-primary-900"
  end

  def test_menu_twice
    assert_equal 2, output.scan('href="/b/docs/teams/"').size
  end
end
