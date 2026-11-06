require "erb"
require "fileutils"
require "nokogiri"
require "set"

module DocsSite
  class Builder
    THEMIFY_DIR = File.join(ROOT, "node_modules/@icon/themify-icons")
    THEMIFY_FILES = %w[themify-icons.css themify-icons.eot themify-icons.svg themify-icons.ttf themify-icons.woff].freeze
    # Written into every build so a later build knows the out dir is safe to replace.
    MARKER = ".docs-site-build"

    NotFoundPage = Struct.new(:html, :url, :absolute_url, :title, :page_title, :description, keyword_init: true)

    def initialize(config:, css_command: nil, out: $stdout)
      @config = config
      @css_command = css_command || default_css_command
      @out = out
    end

    # Writes the whole site into config.out_dir and returns the number of doc pages written.
    def build
      prepare_out_dir
      pages = write_pages
      write_static_files
      build_css
      check_links(pages)
      pages.size
    end

    private

    attr_reader :config

    # DOCS_SITE_OUT points tailwind.config.js at the generated HTML;
    # BROWSERSLIST_IGNORE_OLD_DATA silences the "caniuse-lite is outdated" notice.
    def default_css_command
      env = {"DOCS_SITE_OUT" => File.expand_path(config.out_dir), "BROWSERSLIST_IGNORE_OLD_DATA" => "1"}
      ->(css_out_path) {
        system(env, "npx", "tailwindcss", "-c", "tailwind.config.js", "-i", "src/styles.css", "-o", css_out_path, "--minify", chdir: ROOT)
      }
    end

    # Checks the inputs and out dir, then replaces the out dir with an empty, marked one.
    def prepare_out_dir
      docs_dir = config.docs_dir
      raise BuildError, "Docs directory not found: #{docs_dir}" unless Dir.exist?(docs_dir)
      guard_out_dir!
      guard_foreign_out_dir!

      out_dir = config.out_dir
      FileUtils.rm_rf(out_dir)
      FileUtils.mkdir_p(out_dir)
      write(MARKER, "")
    end

    # The out dir is wiped on every build, so it must not be (or contain) the repo or the sources.
    def guard_out_dir!
      out_dir = File.expand_path(config.out_dir)
      protected_dirs = [ROOT, config.source_dir].map { |dir| File.expand_path(dir) }
      return unless protected_dirs.any? { |dir| dir == out_dir || dir.start_with?(File.join(out_dir, "")) }

      raise BuildError, "Refusing to build into #{out_dir}: it would delete the repository or the source files"
    end

    # Only an empty dir or one holding a previous docs build (the marker) may be wiped.
    def guard_foreign_out_dir!
      out_dir = File.expand_path(config.out_dir)
      return unless File.exist?(out_dir)
      return if File.directory?(out_dir) && (Dir.empty?(out_dir) || File.exist?(File.join(out_dir, MARKER)))

      raise BuildError, "Refusing to replace #{out_dir}: not empty and not a previous docs build"
    end

    def layout
      @layout ||= Layout.new(config: config, menu: Menu.load(config))
    end

    def link_rewriter
      @link_rewriter ||= LinkRewriter.new(config)
    end

    # Returns {page => rendered document} for every doc page written.
    def write_pages
      doc_files.to_h { |path| write_page(path) }
    end

    def doc_files
      Dir[File.join(config.docs_dir, "**/*.md")].sort
    end

    # Renders one Markdown file into a full page, writes it and returns [page, document].
    def write_page(path)
      slug = Page.slug_for(config.docs_dir, path)
      page = Page.new(slug: slug, html: page_html(path, slug), config: config)
      document = layout.render(page)
      write(page.output_path, document)
      [page, document]
    end

    # Body HTML of one doc: rendered, links rewritten, and the index split into columns.
    def page_html(path, slug)
      html = link_rewriter.rewrite(Renderer.render_file(path), slug: slug)
      (slug == "index") ? IndexLayout.apply(html) : html
    end

    # Everything besides the doc pages and the CSS: assets, root redirect, 404 and .nojekyll.
    def write_static_files
      copy_assets
      write_root_index
      write_not_found
      write(".nojekyll", "")
    end

    # Static images, the menu script and the Themify icon font, at the paths the layout links to.
    def copy_assets
      FileUtils.cp_r(File.join(config.source_dir, "assets/."), config.out_dir)
      FileUtils.mkdir_p(out_path("assets/themify"))
      FileUtils.cp(File.join(config.source_dir, "menu.js"), out_path("assets/menu.js"))
      copy_themify
    end

    # Themify comes from node_modules, so a missing `npm ci` must fail clearly.
    def copy_themify
      unless Dir.exist?(THEMIFY_DIR)
        raise BuildError, "Themify icons not found at #{THEMIFY_DIR}; run `npm ci` first"
      end
      THEMIFY_FILES.each { |name| FileUtils.cp(File.join(THEMIFY_DIR, name), out_path("assets/themify")) }
    end

    # The site root has no content of its own; it redirects to the docs index.
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

    # Pages serves 404.html for unknown paths; give it the normal layout and a way back.
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

    # Tailwind runs last because it scans the generated HTML for class names.
    def build_css
      @out.puts "Building CSS with Tailwind"
      raise BuildError, "Tailwind CSS build failed" unless @css_command.call(out_path("assets/site.css"))
    end

    # Fails the build rather than shipping a 404: every doc link must resolve and every
    # root-relative URL must carry the base path.
    def check_links(pages)
      page_urls = pages.keys.map(&:url).to_set
      failures = pages.flat_map { |page, document| link_failures(page.slug, Nokogiri::HTML5(document), page_urls) }
      raise BuildError, failures.join("\n") if failures.any?
    end

    # Failure messages for one page: broken doc links, then unprefixed URLs.
    def link_failures(slug, doc, page_urls)
      hrefs = attribute_values(doc, "a", "href")
      broken = hrefs.select { |href| broken_doc_link?(href, page_urls) }
      unprefixed = (hrefs + attribute_values(doc, "img", "src")).uniq.select { |url| unprefixed?(url) }
      broken.map { |href| "Broken link in #{slug}: #{href}" } + unprefixed.map { |url| "Unprefixed link in #{slug}: #{url}" }
    end

    # Distinct values of one attribute across all matching tags.
    def attribute_values(doc, tag, attribute)
      doc.css("#{tag}[#{attribute}]").map { |node| node[attribute] }.uniq
    end

    # A link into the docs whose page (ignoring the fragment) was not built.
    def broken_doc_link?(href, page_urls)
      href.start_with?("#{config.base_path}/docs") && !page_urls.include?(href.split("#", 2).first)
    end

    # Under a base path, a root-relative URL without it would 404 on Pages.
    def unprefixed?(url)
      base_path = config.base_path
      !base_path.empty? && url.start_with?("/") && !url.start_with?("#{base_path}/", "//")
    end

    # Writes a file under the out dir, creating its parent directories.
    def write(path, content)
      FileUtils.mkdir_p(File.dirname(out_path(path)))
      File.write(out_path(path), content)
    end

    def out_path(path)
      File.join(config.out_dir, path)
    end
  end
end
