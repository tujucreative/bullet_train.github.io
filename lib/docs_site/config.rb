module DocsSite
  class Config
    DEFAULT_BASE_PATH = "/bullet_train.github.io"
    DEFAULT_SITE_URL = "https://tujucreative.github.io"

    attr_reader :base_path, :out_dir, :source_dir, :docs_dir, :site_url

    def initialize(base_path: nil, out_dir: nil, source_dir: nil, site_url: nil, env: ENV)
      @base_path = normalize_base_path(base_path || env["BASE_PATH"] || DEFAULT_BASE_PATH)
      @out_dir = out_dir || File.join(ROOT, "_site")
      @source_dir = source_dir || File.join(ROOT, "src")
      @docs_dir = File.join(@source_dir, "docs")
      @site_url = (site_url || env["SITE_URL"] || DEFAULT_SITE_URL).to_s.sub(%r{/+\z}, "")
    end

    # Public URL of a doc page; index lives at the docs root.
    def doc_url(slug)
      slug == "index" ? "#{base_path}/docs/" : "#{base_path}/docs/#{slug}/"
    end

    # Prefixes a site-root file path with the base path.
    def asset_url(path)
      "#{base_path}/#{path.delete_prefix("/")}"
    end

    private

    # Accepts "", "/", "x", "/x/" and always yields "" or "/x".
    def normalize_base_path(value)
      value = value.to_s.strip.gsub(%r{/+\z}, "")
      return "" if value.empty?
      value.start_with?("/") ? value : "/#{value}"
    end
  end
end
