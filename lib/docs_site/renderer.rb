require "commonmarker"

module DocsSite
  module Renderer
    module_function

    def render(markdown)
      string = markdown.dup.force_encoding("UTF-8").gsub(".md)", ")")
      Commonmarker.to_html(string, options: {extensions: {header_ids: true}, plugins: {syntax_highlighter: {theme: "InspiredGitHub"}}, render: {width: 120, unsafe: true}}).gsub(/&lt;(\/)?script/, '<\\1script')
    end

    def render_file(path)
      render(File.read(path, encoding: "UTF-8"))
    end
  end
end
