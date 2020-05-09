struct DivisionByZero <: Exception end

reciprocal(x) = x == 0 ? throw(DivisionByZero()) : 1 / x
reciprocale(x) = x == 0 ? error(DivisionByZero()) : 1 / x

mystery(n) =
    1 +
    block() do outer
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
        func()
    catch e
        for pair in handlers
            if isa(e, pair.first)
                pair.second(pair.first)
                break
            end
        end
        throw(e)
    end
end

restarts = Dict()

function restart_bind(restartable, restarts...)
    for r in restarts
        restarts[r.first] = r.second
    end
    return restartable()
end

function invoke_restart(restart, args...)
    restarts[restart](args)
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

block() do escape
    handler_bind(ErrorException => function(c)
                     println("Lol rekt ", c)
                     return_from(escape, "got him")
                 end) do
       reciprocale(0)
    end
end

reciprocal(v) =
    restart_bind(:return_zero => () -> 0,
                 :return_value => identity,
                 :retry_using => reciprocal) do
    value == 0 ? throw(DivisionByZero()) : 1 / value
end

a = handler_bind(DivisionByZero => (c) -> invoke_restart(:return_zero)) do
    reciprocal(0)
end
println(a)
