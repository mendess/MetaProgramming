include("../src/Exceptional.jl")
using .Exceptional
import .Exceptional.*
import .Exceptional.ExceptionalExtended.@fn_types
import .Exceptional.ExceptionalExtended.@handler_case
import .Exceptional.ExceptionalExtended.@restart_case
using Test

struct DivisionByZero <: Exception end

reciprocal(x) = x == 0 ? Exceptional.error(DivisionByZero()) : 1 / x

@testset "block and return_from" begin
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
    @test mystery(0) == 3
    @test mystery(1) == 2
    @test mystery(2) == 4
end

@testset "handler bind keeps throwing" begin
    sentinel = 0
    @test_throws DivisionByZero begin
        handler_bind(DivisionByZero => (c) -> sentinel += 1) do
            reciprocal(0)
        end
    end
    @test sentinel == 1
    @test_throws DivisionByZero handler_bind(DivisionByZero => (c) -> sentinel += 1) do
            handler_bind(DivisionByZero => (c) -> sentinel += 1) do
                reciprocal(0)
            end
        end
    @test sentinel == 3
    struct E <: Exception
        n
    end
    e() = Exceptional.error(E(42))
    @test_throws E begin
        handler_bind(E => (c) -> sentinel = c.n) do
            e()
        end
    end
    @test sentinel == 42
end

@testset "handler_bind and return_from" begin
    @test 2 == let sentinel = 0
        block() do escape
            handler_bind(DivisionByZero => (c) -> (sentinel += 1; return_from(escape, "Done"))) do
                handler_bind(DivisionByZero => (c)->sentinel += 1) do
                    reciprocal(0)
                end
            end
        end
        sentinel
    end
    @test 1 == let sentinel = 0
        block() do escape
            handler_bind(DivisionByZero => (c) -> sentinel += 1) do
                handler_bind(DivisionByZero => function(c)
                                 sentinel += 1
                                 return_from(escape, "Done")
                             end) do
                    reciprocal(0)
                end
            end
        end
        sentinel
    end
end

reciprocal_restart(v) =
    restart_bind(:return_zero => () -> 0,
                 :return_value => identity => (Float64,),
                 :retry_using => ((f) -> f()) => (Function,)) do
        reciprocal(0)
    end

@testset "handler_bind and restarts" begin
    @test 0 == handler_bind(DivisionByZero => (c) -> invoke_restart(:return_zero)) do
        reciprocal_restart(0)
    end
    @test 123 == handler_bind(DivisionByZero => (c) -> invoke_restart(:return_value, 123)) do
        reciprocal_restart(0)
    end
    @test 0.1 == handler_bind(DivisionByZero => (c) -> invoke_restart(:retry_using,
                                                                      () -> reciprocal(10))) do
        reciprocal_restart(0)
    end
    @test 1 == handler_bind(DivisionByZero => (c)->invoke_restart(:return_zero)) do
        1 + reciprocal_restart(0)
    end

    divide(x, y) = x * reciprocal_restart(y)

    @test 6 == handler_bind(DivisionByZero => (c) -> invoke_restart(:return_value, 3)) do
      divide(2, 0)
    end
end

@testset "handler_bind and available_restarts" begin
    function foo(c)
        for restart in (:die_horribly, :return_one, :return_zero)
            if available_restart(restart)
                invoke_restart(restart)
            end
        end
    end

    @test 0 == handler_bind(DivisionByZero => foo) do
        reciprocal_restart(0)
    end
end

infinity() = restart_bind(:just_do_it => () -> 1 / 0) do
    reciprocal_restart(0)
end

@testset "nested restarts" begin
    @test 0 == handler_bind(DivisionByZero => (c)->invoke_restart(:return_zero)) do
        infinity()
    end
    @test 1 == handler_bind(DivisionByZero => (c)->invoke_restart(:return_value, 1)) do
        infinity()
    end
    @test 0.1 == handler_bind(DivisionByZero => (c)->invoke_restart(:retry_using,
                                                                    () -> reciprocal(10))) do
        infinity()
    end
    @test Inf == handler_bind(DivisionByZero => (c)->invoke_restart(:just_do_it)) do
        infinity()
    end
end

struct Foo <: Exception end

@testset "shadowing restarts" begin
    function inner()
        restart_bind(:bar => () -> 1) do
            Exceptional.error(Foo())
        end
    end

    function outer()
        restart_bind(:bar => () -> 2) do
            Exceptional.error(Foo()) + handler_bind(Foo => (c) -> invoke_restart(:bar)) do
                inner()
            end
        end
    end

    function outer2()
        restart_bind(:bar => () -> 2) do
            handler_bind(Foo => (c) -> invoke_restart(:bar)) do
                inner()
            end + Exceptional.error(Foo())
        end
    end

    @test 3 == handler_bind(Foo => (c) -> invoke_restart(:bar)) do
        outer()
    end

    @test 3 == handler_bind(Foo => (c) -> invoke_restart(:bar)) do
        outer2()
    end
end

@testset "signal" begin
    sentinel = 0
    @test_throws ErrorException handler_bind(
            DivisionByZero => (c) -> ExceptionalExtended.signal("lmao")) do
        reciprocal(0)
        sentinel += 1
    end
    @test sentinel == 0
    sentinel = 0
    @test_throws ErrorException handler_bind(DivisionByZero => (c) -> sentinel += 1) do
        handler_bind(DivisionByZero => (c) -> ExceptionalExtended.signal("kek")) do
            reciprocal(0)
        end
    end
    @test sentinel == 0
end

if false
    @testset "interactive" begin
        println("TEST: Pick the `return_zero`")
        @test 0 == handler_bind(DivisionByZero =>
                                (c) -> ExceptionalExtended.invoke_restart_interactive()) do
            reciprocal_restart(0)
        end
        println("TEST: Please return 4.2")
        @test 4.2 == handler_bind(DivisionByZero =>
                     (c) -> ExceptionalExtended.invoke_restart_interactive()) do
            reciprocal_restart(0)
        end
        println("TEST: Pick just_do_it")
        @test Inf == handler_bind(DivisionByZero =>
                                  (c) -> ExceptionalExtended.invoke_restart_interactive()) do
            infinity()
        end

        function more_complex()
            restart_bind(:lots_params => ((a, b, c) -> a + b() + c) => (Int, Function, Int)) do
                reciprocal_restart(0)
            end
        end
        println("TEST: Pick lots_params and return 1, 2, and 3")
        @test 6 == handler_bind(DivisionByZero =>
                                (c) -> ExceptionalExtended.invoke_restart_interactive()) do
            more_complex()
        end
        println("TEST: Pick cancel")
        @test_throws ErrorException handler_bind(DivisionByZero =>
                                  (c) -> ExceptionalExtended.invoke_restart_interactive()) do
            more_complex()
        end
        @test length(Exceptional.RESTARTS_STACK) == 0
        println("TEST: Pick return_from")
        @test 0 == block() do token
            handler_bind(DivisionByZero =>
                         (c) -> ExceptionalExtended.invoke_restart_interactive()) do
                restart_bind(:return_from => () -> return_from(token, 0)) do
                    more_complex()
                end
            end
        end
        @test length(Exceptional.RESTARTS_STACK) == 0
    end
end

reciprocal_macro(v) = restart_bind(
                 :return_zero => () -> 0,
                 :return_value => (@fn_types (c::Float64) -> c),
                 :retry_using => @fn_types (f::Function) -> f()) do
        reciprocal(0)
    end

more_complex() =
    restart_bind(:lots_params => @fn_types (a::Int, b::Function, c::Int) -> a + b() + c) do
        reciprocal_restart(0)
    end

if false
    @testset "fn_types macro" begin
        println("TEST: Please return 4.2")
        @test 4.2 == handler_bind(DivisionByZero =>
                     (c) -> ExceptionalExtended.invoke_restart_interactive()) do
            reciprocal_restart(0)
        end

        function more_complex()
            restart_bind(:lots_params => ((a, b, c) -> a + b() + c) => (Int, Function, Int)) do
                reciprocal_restart(0)
            end
        end
        println("TEST: Pick lots_params and return 1, 2, and 3")
        @test 6 == handler_bind(DivisionByZero =>
                                (c) -> ExceptionalExtended.invoke_restart_interactive()) do
            more_complex()
        end
    end
end

@testset "handler_case macro" begin
    @test 1 == @handler_case reciprocal(0) begin
        c::DivisionByZero = 1
    end
    @test 1 == @handler_case reciprocal(0) begin
        c::DivisionByZero = @handler_case reciprocal(0) c::DivisionByZero = 1
    end
    struct E <: Exception
        n
    end
    e() = Exceptional.error(E(42))
    @test 42 == @handler_case e() begin
        c::DivisionByZero = 1
        c::E = c.n
    end
    @test 42 == @handler_case e() begin
        c::DivisionByZero = 1
        c::E = @handler_case reciprocal(0) begin
            d::DivisionByZero =  c.n
            d::E = d.n * 2
        end
    end
    @test 84 == @handler_case e() begin
        c::DivisionByZero = 1
        c::E = @handler_case e() begin
            d::DivisionByZero = c.n
            d::E = d.n * 2
        end
    end
    @test 123 == @handler_case e() begin
        c::DivisionByZero = 666
        c = 123
    end
    good_boy() = 1337
    @test good_boy() == @handler_case good_boy() begin
        c::DivisionByZero = 666
    end
end

@testset "restart_case macro" begin
    reciprocal_macro(v) = @restart_case reciprocal(0) begin
        :return_zero => () -> 0
        :return_value => (c::Number) -> c
        :retry_using => (f::Function) -> f()
        :return_add => (c::Number, b::Number) -> c + b
        :return_add2 => (c, b::Number) -> c + b
        :return_add3 => (c, b) -> c + b
        :return_v => (c) -> c
    end

    @test 0 == handler_bind(DivisionByZero => (c) -> invoke_restart(:return_zero)) do
        reciprocal_macro(0)
    end
    @test 123 == handler_bind(DivisionByZero => (c) -> invoke_restart(:return_value, 123)) do
        reciprocal_macro(0)
    end
    @test 0.1 == handler_bind(DivisionByZero => (c) -> invoke_restart(:retry_using,
                                                                      () -> reciprocal(10))) do
        reciprocal_macro(0)
    end
    @test 1 == handler_bind(DivisionByZero => (c)->invoke_restart(:return_zero)) do
        1 + reciprocal_macro(0)
    end

    divide(x, y) = x * reciprocal_macro(y)

    @test 6 == handler_bind(DivisionByZero => (c) -> invoke_restart(:return_value, 3)) do
      divide(2, 0)
    end
end

