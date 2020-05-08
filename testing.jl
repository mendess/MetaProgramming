struct DivisionByZero <: Exception end

function reciprocal(x)
    x == 0 ?
    error(DivisionByZero()) :
    1 / x
end

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
        print(e[1])
        if e[1] == flag
            return e[2]
        else
        end
    end
end


function return_from(name, value=nothing)
    throw((name, value));
end

mystery(0)

try
    reciprocal(0)
catch e
    e
end

function handler_bind(func, handlers...)
    try
        func()
    catch e
        println("catch")
        for pair in handlers
            println(typeof(e))
            println(pair.first)
            println(pair.second)
            if typeof(e) == pair.first
                yield(pair.second)
            end
        end
    end
    println("ups")
end
#=
handler_bind(()->reciprocal(0),
DivisionByZero =>
(c)->println("I saw a division by zero")) =#
print(reciprocal(0))
