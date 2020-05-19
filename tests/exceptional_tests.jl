include("../src/Exceptional.jl")
using .Exceptional
import .Exceptional.*
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
end

@testset "handler_bind and return_from" begin
    @test begin
        sentinel = 0
        block() do escape
            handler_bind(DivisionByZero => (c) -> (sentinel += 1; return_from(escape, "Done"))) do
                handler_bind(DivisionByZero => (c)->sentinel += 1) do
                    reciprocal(0)
                end
            end
        end
        sentinel == 2
    end
    @test begin
        sentinel = 0
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
        sentinel == 1
    end
end

reciprocal_restart(v) =
    restart_bind(:return_zero => () -> 0,
                 :return_value => identity,
                 :retry_using => reciprocal) do
        reciprocal(0)
    end

@testset "handler_bind and restarts" begin
    @test 0 == handler_bind(DivisionByZero => (c) -> invoke_restart(:return_zero)) do
        reciprocal_restart(0)
    end
    @test 123 == handler_bind(DivisionByZero => (c) -> invoke_restart(:return_value, 123)) do
        reciprocal_restart(0)
    end
    @test 0.1 == handler_bind(DivisionByZero => (c) -> invoke_restart(:retry_using, 10)) do
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
    @test 0.1 == handler_bind(DivisionByZero => (c)->invoke_restart(:retry_using, 10)) do
        infinity()
    end
    @test Inf == handler_bind(DivisionByZero => (c)->invoke_restart(:just_do_it)) do
        infinity()
    end
end

struct Lmao <: Exception end

@testset "shadowing restarts" begin
    function inner()
        restart_bind(:reeeee => () -> 1) do
            Exceptional.error(Lmao())
        end
    end

    function outer()
        restart_bind(:reeeee => () -> 2) do
            Exceptional.error(Lmao()) + handler_bind(Lmao => (c) -> invoke_restart(:reeeee)) do
                inner()
            end
        end
    end

    function outer2()
        restart_bind(:reeeee => () -> 2) do
            handler_bind(Lmao => (c) -> invoke_restart(:reeeee)) do
                inner()
            end + Exceptional.error(Lmao())
        end
    end

    @test 3 == handler_bind(Lmao => (c) -> invoke_restart(:reeeee)) do
        outer()
    end

    @test 3 == handler_bind(Lmao => (c) -> invoke_restart(:reeeee)) do
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

#= @test 0 == handler_bind(DivisionByZero => (c) -> ExceptionalExtended.invoke_restart_mode(:interactive)) do =#
#=     reciprocal_restart(0) =#
#= end =#
