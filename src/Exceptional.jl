module Exceptional

export error,
       block,
       return_from,
       available_restart,
       invoke_restart,
       restart_bind,
       handler_bind
export ExceptionalExtended

include("Stack.jl")

using .stack
import .stack.*

struct RestartResult{T} <: Exception result::T end

struct RestartNotFound <: Exception end

struct ReturnFrom <: Exception
    token
    value
end

global COUNTER = 0

global RESTARTS_STACK = Stack{Dict{Symbol, Pair{Function, Union{Nothing, Tuple}}}}()

global HANDLER_STACK = Stack{Vector{Pair{DataType, Function}}}()

function error(err)
    while (hs = pop!(HANDLER_STACK)) != nothing
        for h in hs
            if err isa h.first
                try
                    h.second(err)
                catch e
                    if e isa RestartResult
                        return e.result
                    else
                        rethrow(e)
                    end
                end
            end
        end
    end
    throw(err)
end

function block(func)
    global COUNTER
    token = COUNTER
    COUNTER += 1
    try
        func(token)
    catch e
        if e isa ReturnFrom && e.token == token
            e.value
        else
            rethrow(e)
        end
    end
end

function return_from(token, value=nothing)
    throw(ReturnFrom(token, value));
end

function handler_bind(func, handlers...)
    a::Vector{Pair{DataType, Function}} = collect(handlers)
    push!(HANDLER_STACK, a)
    func()
end

function restart_bind(restartable, restarts...)
    a = Dict{Symbol, Pair{Function, Union{Nothing, Tuple}}}();
    for r in restarts
        try
            # if r isa Pair{Symbol, Pair}
            a[r.first] = r.second.first => r.second.second
        catch e
            if e isa ErrorException
            # elseif r isa Pair
                try
                    a[r.first] = r.second => nothing
                catch
                    error("Error r isa $(typeof(r))")
                end
            else
                rethrow(e)
            end
        end
    end
    push!(RESTARTS_STACK, a)
    try
        restartable()
    finally
        pop!(RESTARTS_STACK)
    end
end

function invoke_restart(restart, args...)
    while (map = peek(RESTARTS_STACK)) != nothing
        if haskey(map, restart)
            throw(RestartResult(map[restart].first(args...)))
        else
            pop!(RESTARTS_STACK)
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

include("ExceptionalExtended.jl")
end
