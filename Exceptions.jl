#=
function block(func)
end

function return_from(name, value = nothing)
end

function available_restart(name)
end

function invoke_restart(name, args...)
end

function restart_bind(func, restarts...)
end

function error(exception::Exception)
end =#

function handler_bind(func, handlers...)
    try
        func()
    catch e
        println("catch" + e)
        for pair in handlers
            if e isa pair.first
                return pair.second
            end
        end
        throw(e)
    end

    println("ups")
end

