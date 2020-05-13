module Exceptional
include("Stack.jl")
using .stack
import .stack.*

export error,
       block,
       return_from,
       available_restart,
       invoke_restart,
       restart_bind,
       handler_bind

struct RestartResult{T} <: Exception result::T end

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
    push!(RESTARTS_STACK, Dict{Symbol,Function}(restarts...))
    restartable()
end

function invoke_restart(restart, args...)
    while (map = pop!(RESTARTS_STACK)) != nothing
        if haskey(map, restart)
            throw(RestartResult(map[restart](args...)))
        end
    end
    throw(RestartNotFound)
end

function available_restart(restart)
    f(map) = haskey(map, restart)
    for _ in Iterators.filter(f, RESTARTS_STACK)
        return true
    end
    return false
end

end

