module DocsSite
  # Small string helpers that would otherwise come from ActiveSupport.
  module Text
    module_function

    # Rails' String#truncate with the default "..." omission, without ActiveSupport.
    def truncate(text, length)
      (text.length > length) ? "#{text[0, length - 3]}..." : text
    end
  end
end
