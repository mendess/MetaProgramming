module ExceptionalExtended

export signal, invoke_restart_mode

using ..Exceptional
import ..Exceptional.invoke_restart
import ..Exceptional.RESTARTS_STACK

function signal(e)
    Base.error(e)
end

function invoke_restart_mode(mode)
    if mode == :interactive
        println("Choose a restart:")
        i = 0
        count = 1
        restarts_table = []
        for restart_group in RESTARTS_STACK
            for (key, _) in restart_group
                println(" "^i, "$count: $key")
                push!(restarts_table, key)
                count += 1
            end
            i += 1
        end
        pick = parse(Int64, readline(stdin))
        invoke_restart(restarts_table[pick])
    else
        Base.error("Invalid restart mode")
    end
end


end
