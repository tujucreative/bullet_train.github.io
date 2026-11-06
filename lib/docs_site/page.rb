require "nokogiri"

module DocsSite
  class Page
    SITE_NAME = "Bullet Train Developer Documentation"
    DESCRIPTION_LIMIT = 200

    attr_reader :slug, :html

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

    def output_path
      (slug == "index") ? "docs/index.html" : "docs/#{slug}/index.html"
    end

    def absolute_url
      @config.site_url + url
    end

    def title
      text = fragment.at_css("h1")&.text.to_s.strip
      text.empty? ? SITE_NAME : text
    end

    def page_title
      [SITE_NAME, title].uniq.reverse.join(" — ")
    end

    def description
      paragraph = fragment.at_css("p")
      return SITE_NAME unless paragraph

      heading = paragraph.xpath("preceding-sibling::h2").last
      text = [heading&.text.to_s.strip, paragraph.text.strip].reject(&:empty?).join(" — ")
      return SITE_NAME if text.empty?

      (text.length > DESCRIPTION_LIMIT) ? "#{text[0, DESCRIPTION_LIMIT - 3]}..." : text
    end

    private

    def fragment
      @fragment ||= Nokogiri::HTML5.fragment(html)
    end
  end
end
