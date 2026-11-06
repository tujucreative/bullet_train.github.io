require "test_helper"

class PageTest < Minitest::Test
  def config
    DocsSite::Config.new(base_path: "")
  end

  def page(slug, html)
    DocsSite::Page.new(slug: slug, html: html, config: config)
  end

  def test_index_paths
    p = page("index", "<p>x</p>")
    assert_equal "/docs/", p.url
    assert_equal "docs/index.html", p.output_path
  end

  def test_nested_paths
    p = page("billing/stripe", "<p>x</p>")
    assert_equal "/docs/billing/stripe/", p.url
    assert_equal "docs/billing/stripe/index.html", p.output_path
    assert_equal "https://tujucreative.github.io/docs/billing/stripe/", p.absolute_url
  end

  def test_title_and_page_title
    p = page("teams", "<h1>Teams</h1><p>x</p>")
    assert_equal "Teams", p.title
    assert_equal "Teams — Bullet Train Developer Documentation", p.page_title
  end

  def test_title_ignores_empty_anchor
    p = page("teams", '<h1><a class="anchor" href="#teams"></a> Teams </h1>')
    assert_equal "Teams", p.title
  end

  def test_no_h1_fallback
    p = page("x", "<p>x</p>")
    assert_equal DocsSite::Page::SITE_NAME, p.title
    assert_equal DocsSite::Page::SITE_NAME, p.page_title
  end

  def test_description_with_preceding_h2
    assert_equal "Intro — Hello", page("x", "<h1>T</h1><h2>Intro</h2><p>Hello</p>").description
  end

  def test_description_without_h2
    assert_equal "Hello", page("x", "<h1>T</h1><p>Hello</p>").description
  end

  def test_description_no_paragraph
    assert_equal DocsSite::Page::SITE_NAME, page("x", "<h1>T</h1><pre>x</pre>").description
  end

  def test_description_truncates
    d = page("x", "<p>#{"a" * 300}</p>").description
    assert_equal 200, d.length
    assert d.end_with?("...")
  end

  def test_slug_for
    assert_equal "webhooks/incoming", DocsSite::Page.slug_for("/a/docs", "/a/docs/webhooks/incoming.md")
  end
end
