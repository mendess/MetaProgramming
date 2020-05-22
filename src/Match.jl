module Match

export @match

macro match(item, arms)
    val = gensym(:val)
    quote
        let $val = $(esc(item))
            $(begin
                  code = :nothing
                  for e in reverse(filter((e) -> e isa Expr, arms.args))
                      code = make_match(val, e, code, item)
                  end
                  code
              end)
        end
    end
end

function make_match(val, e, code, original)
    (pattern, value) = e.args[2:3]
    test = if pattern == :_ || pattern == original
        :true
    elseif hasproperty(pattern, :args) && pattern.args[1] == :(:)
        (lower, upper) = pattern.args[2:3]
        :($(esc(lower)) <= $val && $val <= $(esc(upper)))
    else
        :($val == $(esc(pattern)))
    end
    quote
        if $test
            $(replace_underscore(esc_vars(value), val))
        else
            $code
        end
    end
end

esc_vars(s)                  = s != :_ ? esc(s) : s
esc_vars(arr::AbstractArray) = [esc_vars(a) for a in arr]
esc_vars(ex::Expr)           = Expr(ex.head, esc_vars(ex.args)...)

replace_underscore(value, val)               = value == :_ ? val : value
replace_underscore(args::AbstractArray, val) = [replace_underscore(x, val) for x in args]
replace_underscore(ex::Expr, val)            = Expr(ex.head, replace_underscore(ex.args, val)...)

end
