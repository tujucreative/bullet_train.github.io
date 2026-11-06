require "nokogiri"
require "uri"

module DocsSite
  class LinkRewriter
    BULLET_TRAIN_ORIGIN = "https://bullettrain.co"
    UPGRADE_IMAGES = "#{BULLET_TRAIN_ORIGIN}/upgrade-images/"
    DOCS_ORIGIN = "#{BULLET_TRAIN_ORIGIN}/docs"
    # Corrects a broken link in upstream v1.45.1 docs, keyed by [page slug, href as written in the source].
    LINK_FIXUPS = {["themes/on-jumpstart-pro-projects", "indirection"] => "/docs/indirection"}.freeze

    def initialize(config)
      @config = config
    end

    def rewrite(html, slug:)
      fragment = Nokogiri::HTML5.fragment(html)
      fragment.css("a[href]").each { |node| node["href"] = rewrite_value(node["href"], slug) }
      fragment.css("img[src]").each { |node| node["src"] = rewrite_value(node["src"], slug) }
      fragment.to_html
    end

    private

    def rewrite_value(value, slug)
      value = LINK_FIXUPS.fetch([slug, value], value)
      if value.start_with?(UPGRADE_IMAGES)
        @config.asset_url("upgrade-images/#{value.delete_prefix(UPGRADE_IMAGES)}")
      elsif value.start_with?(DOCS_ORIGIN)
        rewrite_docs_path(value.delete_prefix(BULLET_TRAIN_ORIGIN)) || value
      elsif relative?(value)
        resolve_relative(value, slug)
      else
        rewrite_docs_path(value) || value
      end
    end

    def relative?(value)
      !value.match?(/\A[a-zA-Z][a-zA-Z0-9+.-]*:/) && !value.start_with?("/", "#")
    end

    def resolve_relative(value, slug)
      uri = URI.join("https://h/docs/#{slug}", value)
      return value unless uri.path.start_with?("/docs")
      target = uri.fragment ? "#{uri.path}##{uri.fragment}" : uri.path
      rewrite_docs_path(target) || value
    rescue URI::Error
      value
    end

    # Returns nil when the path is not a /docs path.
    def rewrite_docs_path(value)
      path, fragment = value.split("#", 2)
      return nil unless path == "/docs" || path.start_with?("/docs/")
      path = path.delete_suffix("/").delete_suffix(".md")
      doc_slug = path.delete_prefix("/docs").delete_prefix("/")
      doc_slug = "index" if doc_slug.empty?
      url = @config.doc_url(doc_slug)
      fragment ? "#{url}##{fragment}" : url
    end
  end
end
