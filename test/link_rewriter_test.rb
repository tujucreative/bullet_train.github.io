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

  def test_upstream_link_fixup
    out = rw(a("indirection"), slug: "themes/on-jumpstart-pro-projects", base: "/b")
    assert_includes out, 'href="/b/docs/indirection/"'
  end

  def test_link_fixup_limited_to_its_page
    assert_includes rw(a("indirection"), slug: "themes"), 'href="/docs/indirection/"'
    assert_includes rw(a("indirection"), slug: "themes/on-other-rails-projects"), 'href="/docs/themes/indirection/"'
  end

  def test_unchanged_links
    ["https://bullettrain.co", "https://github.com/bullet-train-co/magic_test", "#time-based-usage-limits", "mailto:a@b.c"].each do |href|
      assert_includes rw(a(href)), %(href="#{href}")
    end
  end

  def test_root_relative_non_docs_link
    assert_includes rw(a("/users/sign_up")), 'href="https://bullettrain.co/users/sign_up"'
  end

  def test_root_relative_non_docs_link_with_fragment_and_base
    out = rw(a("/pricing#plans"), base: "/bullet_train.github.io")
    assert_includes out, 'href="https://bullettrain.co/pricing#plans"'
  end

  def test_protocol_relative_unchanged
    assert_includes rw(a("//example.com/x")), 'href="//example.com/x"'
  end

  def test_relative_img_unchanged
    assert_includes rw('<img src="foo.png">', slug: "teams"), 'src="foo.png"'
  end

  def test_root_relative_img
    assert_includes rw('<img src="/images/x.png">', base: "/b"), 'src="https://bullettrain.co/images/x.png"'
  end

  def test_preserves_style_and_utf8
    html = '<pre style="background-color:#fff;"><code>🚅 &amp; x</code></pre>'
    assert_equal html, rw(html)
  end
end
