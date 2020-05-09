struct DivisionByZero <: Exception end
struct RestartResult <: Exception
    result
end

reciprocal(x) = x == 0 ? throw(DivisionByZero()) : 1 / x
reciprocale(x) = x == 0 ? error(DivisionByZero()) : 1 / x

mystery(n) =
    1 + block() do outer
        1 +
        block() do inner
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

#####################################
counter = 0
function block(func)
    global counter
    flag = counter
    counter =  counter + 1
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

a = block() do escape
    handler_bind(DivisionByZero => (c) -> (println("I saw it too"); return_from(escape, "Done"))) do
        handler_bind(DivisionByZero => (c) -> println("I saw a division by zero")) do
            reciprocal(0)
        end
    end
end
println(a)

a = block() do escape
    handler_bind(DivisionByZero => (c) -> println("I saw a division by zero")) do
        handler_bind(DivisionByZero => (c) -> (println("I saw it too"); return_from(escape, "Done"))) do
            reciprocal(0)
        end
    end
end

reciprocal(v) =
    restart_bind(:return_zero => () -> 0,
                 :return_value => identity,
                 :retry_using => reciprocal) do
    v == 0 ? throw(DivisionByZero()) : 1 / v
end

a = handler_bind(DivisionByZero => (c) -> invoke_restart(:return_zero)) do
    reciprocal(0)
end
println(a)
