require "set"
require "yaml"

module DocsSite
  class Menu
    Section = Struct.new(:title, :items)
    Item = Struct.new(:label, :url, :icon, :external, :slug)

    attr_reader :sections

    def self.load(config)
      data = YAML.safe_load(File.read(File.join(config.source_dir, "menu.yml"), encoding: "UTF-8"))
      new(config, data.fetch("sections"))
    end

    # Internal doc URLs (as written on the live site, minus ".md") found in
    # the upstream docs layout.
    def self.upstream_urls(layout_erb)
      layout_erb.scan(/url: '(\/docs[^']*)'/).flatten.map { |url| url.delete_suffix(".md") }.to_set
    end

    def initialize(config, raw_sections)
      @raw_urls = Set.new
      @sections = raw_sections.map do |section|
        Section.new(section.fetch("title"), section.fetch("items").map { |item| build_item(config, item) })
      end
    end

    # Raw yml URLs of internal items.
    def internal_urls
      @raw_urls.dup
    end

    def active?(item, page_url)
      item.url == page_url
    end

    private

    def build_item(config, raw)
      url = raw.fetch("url")
      if raw["external"]
        Item.new(raw.fetch("label"), url, raw["icon"], true, nil)
      else
        @raw_urls << url
        slug = (url == "/docs") ? "index" : url.delete_prefix("/docs/")
        Item.new(raw.fetch("label"), config.doc_url(slug), raw["icon"], false, slug)
      end
    end
  end
end
