require "test_helper"

class TextTest < Minitest::Test
  def test_short_text_unchanged
    assert_equal "abc", DocsSite::Text.truncate("abc", 3)
  end

  def test_long_text_truncated_to_length
    assert_equal "abcd...", DocsSite::Text.truncate("abcdefghij", 7)
  end
end
