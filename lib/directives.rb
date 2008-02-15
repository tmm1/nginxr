module Nginx
  class Directive
    attr_accessor :name, :args, :children
    def initialize(name, args = nil, children = nil)
      @name = name
      @args = args
      @children = children
    end
    def render(l = 0)
      TAB*l + @name + 
        @args.map{|a| " " + render_option(a) }.join +
        (@children ? render_children(l) : ";")
    end
    def render_option(a)
      case a
      when String
        a[' '] ? "'#{a}'" : a
      when Symbol
        a.to_s
      when Hash
        a.map{|k,v| "#{render_option(k)}=#{render_option(v)}" }.join(" ")
      when Numeric
        a.to_s
      when Regexp
        a.to_nginx_regexp
      else
        raise "Unknown option type: #{a.inspect}"
      end
    end
    def render_children(l)
      " {\n" + @children.render(l+1) + TAB*l + "}"
    end
  end
  class IfDirective < Directive
    def initialize(expr, children)
      @expr = expr
      @children = children
    end
    def render(l = 0)
      TAB*l + "if (#{@expr})" + render_children(l)
    end
  end
  class Directives < Array
    def render(l = 0)
      map{|d| d.render(l) }.join("\n") + "\n"
    end
  end
end
