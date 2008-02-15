module Nginx
  TAB = "  "
  class Config
    attr_accessor :body, :path
    def initialize(path, &block)
      @path = path
      @body = Builder.build(&block).render
    end
  end
  
  class Builder
    def self.build(&block)
      ctx = new
      ctx.instance_eval(&block)
      ctx.directives
    end
    
    attr_accessor :directives
    
    def initialize
      @directives = Directives.new
    end
    
    def method_missing(name, *args, &block)
      @directives << Directive.new(name.to_s, args, block ? self.class.build(&block) : nil)
      nil
    end
    
    def location(pattern, option = nil, &block)
      op = case pattern
      when String, Symbol
        case option.to_s[0,2]
        when 'st' # strict
          '='
        when 'no' # no_regexps
          '^~'
        else
          nil
        end
      when Regexp
        pattern.casefold? ? '~*' : '~'
      when nil
        nil
      else
        raise "Wrong pattern for location directive! (#{pattern.inspect})"
      end
      @directives << Directive.new('location', [op, pattern].compact, self.class.build(&block))
      nil
    end
    
    def _include(path)
      @directives << Directive.new('include', [path])
    end
    
    def _if(expr, &block)
      @directives << IfDirective.new(expr, self.class.build(&block))
    end 
  end
end