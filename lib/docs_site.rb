module DocsSite
  ROOT = File.expand_path("..", __dir__)

  class BuildError < StandardError; end
end

Dir[File.join(__dir__, "docs_site", "*.rb")].sort.each { |file| require file }
