include("../src/Exceptional.jl")
using .Exceptional
import .Exceptional.*
import .Exceptional.ExceptionalExtended.@fn_types
import .Exceptional.ExceptionalExtended.@handler_case
import .Exceptional.ExceptionalExtended.@restart_case
using Test

struct DivisionByZero <: Exception end

reciprocal(x) = x == 0 ? Exceptional.error(DivisionByZero()) : 1 / x

reciprocal_restart(v) =
    restart_bind(:return_zero => () -> 0,
                 :return_value => identity => (Float64,),
                 :retry_using => ((f) -> f()) => (Function,)) do
        reciprocal(0)
    end

infinity() = restart_bind(:just_do_it => () -> 1 / 0) do
    reciprocal_restart(0)
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
        @test_throws DivisionByZero handler_bind(DivisionByZero =>
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

print("\e[34mNOTE:\e[0m This should give a warning like so: ")
println("\e[33mWARNING:\e[0m Type of 'c' not supplied, using 'String'")
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

