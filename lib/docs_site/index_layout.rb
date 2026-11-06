module DocsSite
  module IndexLayout
    COLUMNS = 3

    def self.apply(html)
      start = html.index(/<h2[\s>]/)
      return html unless start

      header = html[0, start]
      groups = html[start..].split(/(?=<h2[\s>])/)
      columns = in_groups(groups, COLUMNS).map { |group| "<div>#{group.join}</div>" }
      "#{header}<div class=\"xl:grid grid-cols-3 gap-20\">#{columns.join}</div>"
    end

    # Matches ActiveSupport's Array#in_groups(n, false) except that short
    # groups are not padded: the first `size % n` groups get one extra item.
    def self.in_groups(array, count)
      quotient, remainder = array.size.divmod(count)
      start = 0
      Array.new(count) do |index|
        length = quotient + ((index < remainder) ? 1 : 0)
        slice = array[start, length]
        start += length
        slice
      end
    end
  end
end
