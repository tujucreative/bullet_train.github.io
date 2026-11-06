require "erb"

module DocsSite
  class Layout
    include ERB::Util

    IMAGE_URL = "https://avatars.githubusercontent.com/u/5976880?s=280&v=4"

    def initialize(config:, menu:, template_path: File.join(config.source_dir, "layout.html.erb"))
      @config = config
      @menu = menu
      # `capture` in templates relies on eoutvar: "@output".
      @template = ERB.new(File.read(template_path, encoding: "UTF-8"), trim_mode: "-", eoutvar: "@output")
    end

    # Wraps one page in the site shell (head, menu, content card).
    def render(page)
      @template.result(binding)
    end

    private

    attr_reader :config, :menu

    # Renders the block's template output into a string instead of the page.
    def capture
      mark = @output.length
      yield
      @output.slice!(mark..)
    end

    def asset_url(path)
      config.asset_url(path)
    end
  end
end
