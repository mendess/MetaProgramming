include("Exceptional.jl")
using .Exceptional
import .Exceptional.*

struct DivisionByZero <: Exception end

reciprocal(x) = x == 0 ? throw(DivisionByZero()) : 1 / x
reciprocale(x) = x == 0 ? error(DivisionByZero()) : 1 / x

mystery(n) =
    1 + block() do outer
        1 +
        block() do inner
            1 +
            if n == 0
                return_from(inner, 1)
            elseif n == 1
                return_from(outer, 1)
            else
                1
            end
        end
    end

a = block() do escape
    handler_bind(DivisionByZero => (c) -> (println("I saw it too"); return_from(escape, "Done"))) do
        handler_bind(DivisionByZero => (c) -> println("I saw a division by zero")) do
            reciprocal(0)
        end
    end
end
println(a)

a = block() do escape
    handler_bind(DivisionByZero => (c) -> println("I saw a division by zero")) do
        handler_bind(DivisionByZero => (c) -> (println("I saw it too"); return_from(escape, "Done"))) do
            reciprocal(0)
        end
    end
end

reciprocal(v) =
    restart_bind(:return_zero => () -> 0,
                 :return_value => identity,
                 :retry_using => reciprocal) do
        v == 0 ? throw(DivisionByZero()) : 1 / v
    end

a = handler_bind(DivisionByZero => (c) -> invoke_restart(:return_zero)) do
    reciprocal(0)
end
println(a)
