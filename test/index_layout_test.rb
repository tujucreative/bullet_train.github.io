require "test_helper"

class IndexLayoutTest < Minitest::Test
  def test_in_groups
    assert_equal [[1, 2, 3], [4, 5], [6, 7]], DocsSite::IndexLayout.in_groups((1..7).to_a, 3)
    assert_equal [[1], [2], []], DocsSite::IndexLayout.in_groups([1, 2], 3)
  end

  def test_apply
    html = "<h1>Docs</h1><p>i</p><h2>A</h2><ul></ul><h2>B</h2><h2>C</h2><h2>D</h2>"
    out = DocsSite::IndexLayout.apply(html)
    assert out.start_with?("<h1>Docs</h1><p>i</p>")
    assert_includes out, "xl:grid grid-cols-3 gap-20"
    grid = Nokogiri::HTML5.fragment(out).at_css("div.grid-cols-3")
    cols = grid.element_children.select { |n| n.name == "div" }
    assert_equal 3, cols.length
    assert_includes cols[0].to_html, "<h2>A</h2>"
    assert_includes cols[0].to_html, "<h2>B</h2>"
  end

  def test_apply_keeps_h2_attributes
    out = DocsSite::IndexLayout.apply('<p>i</p><h2 id="a">A</h2><h2 id="b">B</h2>')
    assert_includes out, '<h2 id="a">A</h2>'
    assert_includes out, '<h2 id="b">B</h2>'
  end

  def test_apply_without_h2
    html = "<h1>Docs</h1><p>i</p>"
    assert_equal html, DocsSite::IndexLayout.apply(html)
  end
end
