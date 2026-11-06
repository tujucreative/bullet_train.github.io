require "test_helper"

class LinkRewriterTest < Minitest::Test
  def rw(html, slug: "index", base: "")
    config = DocsSite::Config.new(base_path: base, env: {})
    DocsSite::LinkRewriter.new(config).rewrite(html, slug: slug)
  end

  def a(href)
    %(<a href="#{href}">x</a>)
  end

  def test_absolute_doc_link
    assert_includes rw(a("/docs/getting-started")), 'href="/docs/getting-started/"'
  end

  def test_absolute_doc_link_with_base
    out = rw(a("/docs/getting-started"), base: "/bullet_train.github.io")
    assert_includes out, 'href="/bullet_train.github.io/docs/getting-started/"'
  end

  def test_md_and_fragment
    assert_includes rw(a("/docs/field-partials/super-select.md#options")), 'href="/docs/field-partials/super-select/#options"'
  end

  def test_docs_root
    assert_includes rw(a("/docs")), 'href="/docs/"'
  end

  def test_docs_root_trailing_slash
    assert_includes rw(a("/docs/")), 'href="/docs/"'
  end

  def test_bullettrain_co_docs_link
    assert_includes rw(a("https://bullettrain.co/docs/super-scaffolding/targets")), 'href="/docs/super-scaffolding/targets/"'
  end

  def test_upgrade_images
    out = rw('<img src="https://bullettrain.co/upgrade-images/1-find-action.png">', base: "/bullet_train.github.io")
    assert_includes out, 'src="/bullet_train.github.io/upgrade-images/1-find-action.png"'
  end

  def test_relative_sibling_with_md_and_fragment
    assert_includes rw(a("./incoming.md#security"), slug: "webhooks/outgoing"), 'href="/docs/webhooks/incoming/#security"'
  end

  def test_relative_self_with_fragment
    assert_includes rw(a("./upgrades#github-action"), slug: "upgrades"), 'href="/docs/upgrades/#github-action"'
  end

  def test_relative_top_level_md
    assert_includes rw(a("./indirection.md"), slug: "themes"), 'href="/docs/indirection/"'
  end

  def test_unchanged_links
    ["https://bullettrain.co", "https://github.com/bullet-train-co/magic_test", "#time-based-usage-limits", "mailto:a@b.c"].each do |href|
      assert_includes rw(a(href)), %(href="#{href}")
    end
  end

  def test_preserves_style_and_utf8
    html = '<pre style="background-color:#fff;"><code>🚅 &amp; x</code></pre>'
    assert_equal html, rw(html)
  end
end
