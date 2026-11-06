require "erb"
require "fileutils"
require "nokogiri"
require "set"

module DocsSite
  class Builder
    THEMIFY_DIR = File.join(ROOT, "node_modules/@icon/themify-icons")
    THEMIFY_FILES = %w[themify-icons.css themify-icons.eot themify-icons.svg themify-icons.ttf themify-icons.woff].freeze

    NotFoundPage = Struct.new(:html, :url, :absolute_url, :title, :page_title, :description, keyword_init: true)

    # BROWSERSLIST_IGNORE_OLD_DATA silences the "caniuse-lite is outdated" notice.
    DEFAULT_CSS_COMMAND = ->(css_out_path) {
      system({"BROWSERSLIST_IGNORE_OLD_DATA" => "1"}, "npx", "tailwindcss", "-c", "tailwind.config.js", "-i", "src/styles.css", "-o", css_out_path, "--minify", chdir: ROOT)
    }

    def initialize(config:, css_command: nil, out: $stdout)
      @config = config
      @css_command = css_command || DEFAULT_CSS_COMMAND
      @out = out
    end

    # Writes the whole site into config.out_dir and returns the number of doc pages written.
    def build
      raise BuildError, "Docs directory not found: #{config.docs_dir}" unless Dir.exist?(config.docs_dir)

      FileUtils.rm_rf(config.out_dir)
      FileUtils.mkdir_p(config.out_dir)

      pages = write_pages
      copy_assets
      write_root_index
      write_not_found
      write(".nojekyll", "")
      build_css
      check_links(pages)
      pages.size
    end

    private

    attr_reader :config

    def layout
      @layout ||= Layout.new(config: config, menu: Menu.load(config))
    end

    def link_rewriter
      @link_rewriter ||= LinkRewriter.new(config)
    end

    # Returns {page => rendered document} for every doc page written.
    def write_pages
      Dir[File.join(config.docs_dir, "**/*.md")].sort.to_h do |path|
        slug = Page.slug_for(config.docs_dir, path)
        html = link_rewriter.rewrite(Renderer.render_file(path), slug: slug)
        html = IndexLayout.apply(html) if slug == "index"
        page = Page.new(slug: slug, html: html, config: config)
        document = layout.render(page)
        write(page.output_path, document)
        [page, document]
      end
    end

    def copy_assets
      FileUtils.cp_r(File.join(config.source_dir, "assets/."), config.out_dir)
      FileUtils.mkdir_p(out_path("assets/themify"))
      FileUtils.cp(File.join(config.source_dir, "menu.js"), out_path("assets/menu.js"))
      copy_themify
    end

    def copy_themify
      unless Dir.exist?(THEMIFY_DIR)
        raise BuildError, "Themify icons not found at #{THEMIFY_DIR}; run `npm ci` first"
      end
      THEMIFY_FILES.each { |name| FileUtils.cp(File.join(THEMIFY_DIR, name), out_path("assets/themify")) }
    end

    def write_root_index
      url = ERB::Util.h(config.doc_url("index"))
      write("index.html", <<~HTML)
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="utf-8" />
            <title>#{Page::SITE_NAME}</title>
            <meta http-equiv="refresh" content="0; url=#{url}" />
            <link rel="canonical" href="#{ERB::Util.h(config.site_url)}#{url}" />
          </head>
          <body>
            <p><a href="#{url}">#{Page::SITE_NAME}</a></p>
          </body>
        </html>
      HTML
    end

    def write_not_found
      url = config.asset_url("404.html")
      page = NotFoundPage.new(
        html: %(<h1>Page not found</h1><p><a href="#{ERB::Util.h(config.doc_url("index"))}">Back to the documentation</a></p>),
        url: url,
        absolute_url: config.site_url + url,
        title: "Page not found",
        page_title: "Page not found — #{Page::SITE_NAME}",
        description: Page::SITE_NAME
      )
      write("404.html", layout.render(page))
    end

    def build_css
      @out.puts "Building CSS with Tailwind"
      raise BuildError, "Tailwind CSS build failed" unless @css_command.call(out_path("assets/site.css"))
    end

    def check_links(pages)
      urls = pages.keys.map(&:url).to_set
      prefix = "#{config.base_path}/docs"
      failures = pages.flat_map do |page, document|
        Nokogiri::HTML5(document).css("a[href]").map { |node| node["href"] }.uniq
          .select { |href| href.start_with?(prefix) && !urls.include?(href.split("#", 2).first) }
          .map { |href| "Broken link in #{page.slug}: #{href}" }
      end
      raise BuildError, failures.join("\n") if failures.any?
    end

    def write(path, content)
      FileUtils.mkdir_p(File.dirname(out_path(path)))
      File.write(out_path(path), content)
    end

    def out_path(path)
      File.join(config.out_dir, path)
    end
  end
end
