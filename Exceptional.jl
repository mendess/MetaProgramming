module Exceptional

export block, return_from, available_restart, invoke_restart, restart_bind, handler_bind

struct RestartResult <: Exception
    result
end

COUNTER = 0
function block(func)
    global COUNTER
    flag = COUNTER
    counter =  COUNTER + 1
    try
        func(flag)
    catch e
        if e[1] == flag
            return e[2]
        else
            throw(e)
        end
    end
end

function return_from(name, value=nothing)
    throw((name, value));
end

function handler_bind(func, handlers...)
    try
        return func()
    catch e
        for pair in handlers
            if isa(e, pair.first)
                try
                    return pair.second(pair.first)
                catch e
                    if isa(e, RestartResult)
                        return e.result
                    else
                        throw(e)
                    end
                end
            end
        end
        throw(e)
    end
end

RESTARTS_MAP = Dict{Symbol,Function}()

function restart_bind(restartable, restarts...)
    global RESTARTS_MAP
    for r in restarts
        RESTARTS_MAP[r.first] = r.second
    end
    return restartable()
end

function invoke_restart(restart, args...)
    global RESTARTS_MAP
    throw(RestartResult(RESTARTS_MAP[restart](args...)))
end

function available_restart(restart)
    global RESTARTS_MAP
    haskey(RESTARTS_MAP, restart)
end
end
