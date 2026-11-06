require "test_helper"

class ConfigTest < Minitest::Test
  Config = DocsSite::Config

  def test_defaults
    c = Config.new(env: {})
    assert_equal "/bullet_train.github.io", c.base_path
    assert_equal File.join(DocsSite::ROOT, "_site"), c.out_dir
    assert_equal File.join(DocsSite::ROOT, "src/docs"), c.docs_dir
    assert_equal "https://tujucreative.github.io", c.site_url
  end

  def test_env_base_path
    assert_equal "/x", Config.new(env: {"BASE_PATH" => "/x/"}).base_path
  end

  def test_kwarg_beats_env
    assert_equal "", Config.new(base_path: "", env: {"BASE_PATH" => "/x"}).base_path
  end

  def test_normalizes
    assert_equal "", Config.new(base_path: "/", env: {}).base_path
    assert_equal "/foo", Config.new(base_path: "foo", env: {}).base_path
  end

  def test_doc_url
    c = Config.new(base_path: "", env: {})
    assert_equal "/docs/", c.doc_url("index")
    assert_equal "/docs/billing/stripe/", c.doc_url("billing/stripe")
    assert_equal "/bullet_train.github.io/docs/api/", Config.new(env: {}).doc_url("api")
  end

  def test_asset_url
    assert_equal "/assets/site.css", Config.new(base_path: "", env: {}).asset_url("assets/site.css")
    assert_equal "/bullet_train.github.io/logo/logo.png", Config.new(env: {}).asset_url("/logo/logo.png")
  end
end
