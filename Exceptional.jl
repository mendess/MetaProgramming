module Exceptional

export block, return_from, available_restart, invoke_restart, restart_bind, handler_bind

struct RestartResult <: Exception
    result
end

COUNTER = 0

RESTARTS_MAP = Dict{Symbol,Function}()

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
    try
        func()
    catch e
        for pair in handlers
            if isa(e, pair.first)
                try
                    pair.second(pair.first)
                catch e
                    if isa(e, RestartResult)
                        return e.result
                    else
                        throw(e)
                    end
                end
                break
            end
        end
        throw(e)
    end
end

function restart_bind(restartable, restarts...)
    global RESTARTS_MAP
    for r in restarts
        RESTARTS_MAP[r.first] = r.second
    end
    restartable()
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

