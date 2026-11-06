require "date"
require "fileutils"

module DocsSite
  # Replaces the vendored docs snapshot with a checkout of upstream
  # bullet_train-core and records where it came from in src/UPSTREAM.
  class Sync
    REPO = "https://github.com/bullet-train-co/bullet_train-core"
    LAYOUT_PATH = File.join("bullet_train", "app", "views", "layouts", "docs.html.erb")

    def initialize(config:, out: $stdout)
      @config = config
      @out = out
    end

    def call(upstream_dir:, ref:, sha:)
      upstream_docs = File.join(upstream_dir, "bullet_train", "docs")
      raise ArgumentError, "no docs directory at #{upstream_docs}" unless File.directory?(upstream_docs)

      before = snapshot(@config.docs_dir)
      after = snapshot(upstream_docs)
      result = {
        added: (after.keys - before.keys).sort,
        removed: (before.keys - after.keys).sort,
        changed: (before.keys & after.keys).select { |path| before[path] != after[path] }.sort
      }

      replace_docs(upstream_docs)
      write_upstream_file(ref, sha)
      report(result, ref, sha)
      warn_on_menu_drift(upstream_dir)
      result
    end

    private

    # Relative path => file content, for every file under dir.
    def snapshot(dir)
      return {} unless File.directory?(dir)
      Dir.glob("**/*", File::FNM_DOTMATCH, base: dir).each_with_object({}) do |path, files|
        full = File.join(dir, path)
        files[path] = File.binread(full) if File.file?(full)
      end
    end

    def replace_docs(upstream_docs)
      FileUtils.rm_rf(@config.docs_dir)
      FileUtils.mkdir_p(File.dirname(@config.docs_dir))
      FileUtils.cp_r(upstream_docs, @config.docs_dir)
    end

    def write_upstream_file(ref, sha)
      File.write(File.join(@config.source_dir, "UPSTREAM"), <<~TEXT)
        repo: #{REPO}
        ref: #{ref}
        sha: #{sha}
        synced: #{Date.today.iso8601}
      TEXT
    end

    def report(result, ref, sha)
      @out.puts "Synced docs from #{REPO} at #{ref} (#{sha})"
      result.each do |kind, paths|
        @out.puts "#{kind.to_s.capitalize}: #{paths.size}"
        paths.each { |path| @out.puts "  #{path}" }
      end
    end

    def warn_on_menu_drift(upstream_dir)
      layout = File.join(upstream_dir, LAYOUT_PATH)
      return unless File.file?(layout)

      upstream = Menu.upstream_urls(File.read(layout, encoding: "UTF-8"))
      menu = Menu.load(@config).internal_urls
      return if upstream == menu

      @out.puts "WARNING: menu differs from upstream layout; review src/menu.yml"
      @out.puts "  only in upstream: #{format_urls(upstream - menu)}"
      @out.puts "  only in menu.yml: #{format_urls(menu - upstream)}"
    end

    def format_urls(urls)
      urls.empty? ? "(none)" : urls.sort.join(", ")
    end
  end
end
