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

    # Makes the links and images of one rendered doc work under the base path.
    def rewrite(html, slug:)
      fragment = Nokogiri::HTML5.fragment(html)
      fragment.css("a[href]").each { |node| node["href"] = rewrite_href(node["href"], slug) }
      fragment.css("img[src]").each { |node| node["src"] = rewrite_src(node["src"]) }
      fragment.to_html
    end

    private

    # Links may point at other docs (absolute, relative or on bullettrain.co); those become local doc URLs.
    def rewrite_href(value, slug)
      value = LINK_FIXUPS.fetch([slug, value], value)
      if value.start_with?(DOCS_ORIGIN)
        rewrite_docs_path(value.delete_prefix(BULLET_TRAIN_ORIGIN)) || value
      elsif relative?(value)
        resolve_relative(value, slug)
      else
        rewrite_docs_path(value) || rewrite_src(value)
      end
    end

    # Images only need the hosted upgrade images localized and live-site paths sent to bullettrain.co.
    def rewrite_src(value)
      if value.start_with?(UPGRADE_IMAGES)
        @config.asset_url("upgrade-images/#{value.delete_prefix(UPGRADE_IMAGES)}")
      elsif root_relative?(value)
        BULLET_TRAIN_ORIGIN + value
      else
        value
      end
    end

    # Neither a scheme URL, a root path nor a bare fragment, so it depends on the current page.
    def relative?(value)
      !value.match?(/\A[a-zA-Z][a-zA-Z0-9+.-]*:/) && !value.start_with?("/", "#")
    end

    # A non-/docs root path (e.g. /users/sign_up) only exists on the live Rails site, not on Pages.
    def root_relative?(value)
      value.start_with?("/") && !value.start_with?("//")
    end

    # Upstream relative links assume the live URL /docs/<slug> (no trailing slash), so resolve against that.
    def resolve_relative(value, slug)
      uri = URI.join("https://h/docs/#{slug}", value)
      path = uri.path
      return value unless path.start_with?("/docs")
      fragment = uri.fragment
      target = fragment ? "#{path}##{fragment}" : path
      rewrite_docs_path(target) || value
    rescue URI::Error
      value
    end

    # Maps a /docs path (optionally with .md and a fragment) to its local doc URL; nil when not a /docs path.
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
