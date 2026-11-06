require "test_helper"
require "tempfile"

class RendererTest < Minitest::Test
  Renderer = DocsSite::Renderer

  def test_strips_md_in_links
    assert_includes Renderer.render("[a](/docs/foo.md)"), 'href="/docs/foo"'
  end

  def test_heading_ids
    assert_includes Renderer.render("## Sub Title"), 'id="sub-title"'
  end

  def test_highlights_code
    assert_match(/<pre[^>]*style=/, Renderer.render("```ruby\nputs 1\n```\n"))
  end

  def test_raw_html_passes_through
    assert_includes Renderer.render('<i class="ti ti-new-window"></i>'), '<i class="ti ti-new-window"></i>'
  end

  def test_unescapes_script
    html = Renderer.render("<script>x</script>")
    assert_includes html, "<script>"
    refute_includes html, "&lt;script"
  end

  def test_utf8_from_binary_string
    assert_includes Renderer.render("# 🚅 Hi".b), "🚅"
  end

  def test_render_file_utf8
    Tempfile.create(["doc", ".md"]) do |file|
      file.write("# 🚅")
      file.flush
      original = Encoding.default_external
      begin
        silently { Encoding.default_external = Encoding::US_ASCII }
        assert_includes Renderer.render_file(file.path), "🚅"
      ensure
        silently { Encoding.default_external = original }
      end
    end
  end

  private

  def silently
    verbose, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = verbose
  end
end
