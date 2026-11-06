module DocsSite
  # Shared plumbing for the bin/ scripts.
  module CLI
    module_function

    # A BuildError becomes a one-line message on stderr and exit status 1 instead of a backtrace.
    def run(err: $stderr)
      yield
    rescue BuildError => error
      err.puts error.message
      exit 1
    end

    # bin/build and bin/serve both build the site and report the page count the same way.
    def build(config, builder: Builder.new(config: config), out: $stdout, err: $stderr)
      run(err: err) do
        out.puts "Built #{builder.build} pages into #{config.out_dir}"
      end
    end
  end
end
