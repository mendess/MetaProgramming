include("../src/Stack.jl")
using .stack
import .stack.*
using Test

@testset "push" begin
    a = Stack{Int}()
    push!(a, 1)
    @test length(a) == 1
    a = Stack{Int}()
    for i in 1:10000
        push!(a, i)
    end
    @test length(a) == 10000
end

@testset "pop" begin
    a = Stack{Int}()
    for i in 1:10000
        push!(a, i)
    end
    count = length(a)
    while (c = pop!(a)) != nothing
        @test c == count
        count -= 1
    end
    @test count == 0
end

@testset "peek" begin
    a = Stack{Int}()
    for i in 1:10000
        push!(a, i)
    end
    while (c = peek(a)) != nothing
        @test c == pop!(a)
    end
end

@testset "iteration" begin
    a = Stack{Int}()
    for i in 0:10000
        push!(a, i)
    end
    for i in zip(reverse(0:10000), a)
        @test i[1] == i[2]
    end
end

