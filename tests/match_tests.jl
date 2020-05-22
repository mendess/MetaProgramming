include("../src/Match.jl")

import .Match.@match
using Test

@testset "simple" begin
    for i in 1:10
        a = @match i begin
            i => i
        end
        @test a == i
    end
end

@testset "default" begin
    for i in 1:10
        a = @match i begin
            0 => 0
            _ => _
        end
        @test a == i
    end
end

@testset "range" begin
    for i in 0:15
        a = @match i begin
            0:3 => 0
            4:7 => 1
            8:11 => 2
            12:15 => 3
        end
        @test a == i ÷ 4
    end
end

@testset "eval once" begin
    sentinel = 0
    f() = sentinel += 1
    a = @match f() begin
        0 => false
        2 => false
        3 => false
        1 => true
    end
    @test sentinel == 1
    @test a
    a = @match f() begin
        0 => false
        1 => false
        3 => false
        _ => _
    end
    @test sentinel == 2
    @test a == 2
    a = @match f() begin
        0 => false
        1 => false
        3 => f()
    end
    @test sentinel == 4
    @test a == 4
end
