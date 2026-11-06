require "nokogiri"

module DocsSite
  class Page
    SITE_NAME = "Bullet Train Developer Documentation"
    DESCRIPTION_LIMIT = 200

    attr_reader :slug, :html

    # A doc's slug is its path under docs_dir without ".md".
    def self.slug_for(docs_dir, file_path)
      file_path.delete_prefix("#{docs_dir.chomp("/")}/").delete_suffix(".md")
    end

    def initialize(slug:, html:, config:)
      @slug = slug
      @html = html
      @config = config
    end

    def url
      @config.doc_url(slug)
    end

    # Each doc is written as <slug>/index.html so its URL ends in a slash.
    def output_path
      (slug == "index") ? "docs/index.html" : "docs/#{slug}/index.html"
    end

    def absolute_url
      @config.site_url + url
    end

    # First h1 text, as the live layout uses for <title>.
    def title
      text = fragment.at_css("h1")&.text.to_s.strip
      text.empty? ? SITE_NAME : text
    end

    # "<title> — <site name>", or just the site name when the page has no h1.
    def page_title
      [SITE_NAME, title].uniq.reverse.join(" — ")
    end

    # Meta description like the live layout: first paragraph, prefixed by its preceding h2.
    def description
      paragraph = fragment.at_css("p")
      return SITE_NAME unless paragraph

      heading = paragraph.xpath("preceding-sibling::h2").last
      text = [heading&.text.to_s.strip, paragraph.text.strip].reject(&:empty?).join(" — ")
      return SITE_NAME if text.empty?

      Text.truncate(text, DESCRIPTION_LIMIT)
    end

    private

    def fragment
      @fragment ||= Nokogiri::HTML5.fragment(html)
    end
  end
end
