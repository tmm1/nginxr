class ::Regexp
  # Regexp#inspect escapes slashes (\/)
  # Method smartly removes slashes escaping ``\/'' => ``/''
  def to_nginx_regexp
    (" " + inspect[1..-2]).gsub(/([^\\])\\((?:\\\\)*\/)/, "\\1\\2")[1..-1]
  end
end
