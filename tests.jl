include("Exceptional.jl")
using .Exceptional
import .Exceptional.*

struct DivisionByZero <: Exception end

reciprocal(x) = x == 0 ? throw(DivisionByZero()) : 1 / x

function test1()
    sentinel = 0
    try
        handler_bind(DivisionByZero => (c) -> sentinel += 1) do
            reciprocal(0)
        end
        @assert false "Didn't throw"
    catch e
        @assert sentinel == 1
        @assert isa(e, DivisionByZero) "expected $(DivisionByZero) got $(typeof(e))"
    end
end

function test2()
    sentinel = 0
    try
        handler_bind(DivisionByZero => (c) -> sentinel += 1) do
            handler_bind(DivisionByZero => (c) -> sentinel += 1) do
                reciprocal(0)
            end
        end
        @assert false "Didn't throw"
    catch e
        @assert sentinel == 2
        @assert isa(e, DivisionByZero) "expected $(DivisionByZero) got $(typeof(e))"
    end
end

function test3()
    mystery(n) =
        1 + block() do outer
            1 + block() do inner
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
    @assert mystery(0) == 3
    @assert mystery(1) == 2
    @assert mystery(2) == 4
end

function test4()
    sentinel = 0
    try
        block() do escape
            handler_bind(DivisionByZero => (c) -> (sentinel += 1; return_from(escape, "Done"))) do
                handler_bind(DivisionByZero => (c)->sentinel += 1) do
                    reciprocal(0)
                end
            end
        end
        @assert sentinel == 2
    catch e
        @assert false "Threw: $(e)"

    end
end

function test5()
    sentinel = 0
    try
        block() do escape
            handler_bind(DivisionByZero => (c)->sentinel += 1) do
                handler_bind(DivisionByZero => (c) -> (sentinel += 1; return_from(escape, "Done"))) do
                    reciprocal(0)
                end
            end
        end
        @assert sentinel == 1
    catch e
        @assert false "Threw: $(e)"

    end
end

reciprocal_restart(v) =
    restart_bind(:return_zero => () -> 0,
                 :return_value => identity,
                 :retry_using => reciprocal) do
        v == 0 ? throw(DivisionByZero()) : 1 / v
    end
function test6()
    try
        a = handler_bind(DivisionByZero => (c) -> invoke_restart(:return_zero)) do
            reciprocal_restart(0)
        end
        @assert a == 0
    catch e
        @assert false "Threw $(e)"
    end
end

function test7()
    try
        a = handler_bind(DivisionByZero => (c) -> invoke_restart(:return_value, 123)) do
            reciprocal_restart(0)
        end
        @assert a == 123
    catch e
        @assert false "Threw $(e)"
    end
end

function test8()
    try
        a = handler_bind(DivisionByZero => (c) -> invoke_restart(:retry_using, 10)) do
            reciprocal_restart(0)
        end
        @assert a == 0.1
    catch e
        @assert false "Threw $(e)"
    end
end

function test9()
    function foo(c)
        for restart in (:die_horribly, :return_one, :return_zero)
            if available_restart(restart)
                invoke_restart(restart)
            end
        end
    end

    try
        a = handler_bind(DivisionByZero => foo) do
            reciprocal(0)
        end
        @assert a == 0 "Expected 0 got $(a)"
    catch e
        @assert false "Threw $(e)"
    end
end

infinity() = restart_bind(:just_do_it => ()->1/0) do
    reciprocal(0)
end

function test10()
    try
        a = handler_bind(DivisionByZero => (c)->invoke_restart(:return_zero)) do
            infinity()
        end
        @assert a == 0
    catch e
        @assert false "Threw: $(e)"
    end
end

function test11()
    try
        a = handler_bind(DivisionByZero => (c)->invoke_restart(:return_value, 1)) do
            infinity()
        end
        @assert a == 1
    catch e
        @assert false "Threw: $(e)"
    end
end

function test12()
    try
        a = handler_bind(DivisionByZero => (c)->invoke_restart(:retry_using, 10)) do
            infinity()
        end
        @assert a == 0.1
    catch e
        @assert false "Threw: $(e)"
    end
end

function test13()
    try
        a = handler_bind(DivisionByZero => (c)->invoke_restart(:just_do_it)) do
            infinity()
        end
        @assert a == Inf
    catch e
        @assert false "Threw: $(e)"
    end
end

test1()
test2()
test3()
test4()
test5()
test6()
test7()
test8()
test9()
test10()
test11()
test12()
test13()
