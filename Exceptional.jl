module Exceptional
include("Stack.jl")
using .stack
import .stack.*

export error, block, return_from, available_restart, invoke_restart, restart_bind, handler_bind

struct RestartResult{T} <: Exception
    result::T
end

struct RestartNotFound <: Exception end

global COUNTER = 0

global RESTARTS_STACK = Stack{Dict{Symbol,Function}}()

global HANDLER_STACK = Stack{Vector{Pair{DataType, Function}}}()

function error(e)
    while (hs = pop!(HANDLER_STACK)) != nothing
        for h in hs
            if e isa h.first
                try
                    h.second(h.first)
                catch e
                    if e isa RestartResult
                        return e.result
                    else
                        throw(e)
                    end
                end
            end
        end
    end
    throw(e)
end

function block(func)
    global COUNTER
    flag = COUNTER
    COUNTER += 1
    try
        func(flag)
    catch e
        if e.first == flag
            e.second
        else
            throw(e)
        end
    end
end

function return_from(name, value=nothing)
    throw(name => value);
end

function handler_bind(func, handlers...)
    a::Vector{Pair{DataType, Function}} = collect(handlers)
    push!(HANDLER_STACK, a)
    func()
end

function restart_bind(restartable, restarts...)
    restarts_map = Dict{Symbol,Function}()
    for r in restarts
        restarts_map[r.first] = r.second
    end
    global RESTARTS_STACK
    push!(RESTARTS_STACK, restarts_map)
    restartable()
end

function invoke_restart(restart, args...)
    global RESTARTS_STACK
    while (map = pop!(RESTARTS_STACK)) != nothing
        if haskey(map, restart)
            throw(RestartResult(map[restart](args...)))
        end
    end
    throw(RestartNotFound)
end

function available_restart(restart)
    global RESTARTS_STACK
    if length(RESTARTS_STACK) < 1
        false
    else
        for map in RESTARTS_STACK
            if haskey(map, restart)
               return  true
            end
        end
        false
    end
end

end

