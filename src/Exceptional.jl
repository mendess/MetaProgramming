@doc raw"""
This module introduces additional facilities for working with exceptional
situations.
"""
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

@doc raw"""
Signal that an error has occurred in such a way that the functions of this module
can detect. This must be used instead of `Base.throw` otherwise nothing will work.
"""
function error(err)
    while (hs = peek(HANDLER_STACK)) != nothing
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
        pop!(HANDLER_STACK)
    end
    throw(err)
end

@doc raw"""
Start a block that can be returned from. Must be used in conjunction with
`return_from`

# Example
```
f(n) = block() do token
        1 + if n == 0
            return_from(token, 1)
        else
            1
        end
    end
```
"""
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

@doc raw"""
Return from a previous point in the program, optionaly returning a value

See also: `block`
"""
function return_from(token, value=nothing)
    throw(ReturnFrom(token, value));
end

@doc raw"""
Creates a context where exceptions can be witnessed.

# Note:
this will not stop the exception from propagating unless a transfer of
control is invoked in the handler.

```
handler_bind(DivisionByZero => (c) -> println("Tried to divide by 0")) do
    reciprocal(0)
end
```
"""
function handler_bind(func, handlers...)
    a::Vector{Pair{DataType, Function}} = collect(handlers)
    push!(HANDLER_STACK, a)
    try
        func()
    finally
        pop!(HANDLER_STACK)
    end
end

@doc raw"""
Runs a function in a restartable context, during it's exectution, if an exceptional
situation happens it can be restarted using `invoke_restart`.

```
some_restartable(v) = restart_bind(:return_zero => () -> 0) do
    some_function(v)
end

@assert 0 == handler_bind(Except => (c) -> invoke_restart(:return_zero)) do
    Exceptional.error(Except())
end
```
"""
function restart_bind(restartable, restarts...)
    a = Dict{Symbol, Pair{Function, Union{Nothing, Tuple}}}();
    for r in restarts
        if r isa Pair && r.first isa Symbol
            if hasproperty(r.second, :first) && hasproperty(r.second, :second) # if r isa Pair{Symbol, Pair}
                a[r.first] = r.second.first => r.second.second
            else
                a[r.first] = r.second => nothing
            end
        else
            error("Error r isa $(typeof(r))")
        end
    end
    push!(RESTARTS_STACK, a)
    try
        restartable()
    finally
        pop!(RESTARTS_STACK)
    end
end

@doc raw"""
Invoke a previously declared restart

See also `restart_bind`
"""
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

@doc raw"""
Checks if a restart is available at this point.
"""
function available_restart(restart::Symbol)
    f(map) = haskey(map, restart)
    for _ in Iterators.filter(f, RESTARTS_STACK)
        return true
    end
    return false
end

include("ExceptionalExtended.jl")
end
