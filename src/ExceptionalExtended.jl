module ExceptionalExtended

include("Match.jl")
using .Match

export signal, invoke_restart_mode, @fn_types

using ..Exceptional
import ..Exceptional.invoke_restart
import ..Exceptional.RESTARTS_STACK

function signal(e)
    Base.error(e)
end

function prompt(parser, prompt_string)
    while true
        print(prompt_string)
        l = readline(stdin, keep=true)
        if isempty(l)
            return nothing
        else
            @match parser(chomp(l)) begin
                nothing => continue
                _ => return _
            end
        end
    end
end

function invoke_restart_mode(mode)
    if mode == :interactive
        println("Choose a restart:")
        i = 0
        count = 1
        restarts_table = []
        println("0: cancel :: !")
        for restart_group in RESTARTS_STACK
            for (key, val) in restart_group
                if val.second != nothing
                    println("  "^i, "$count: $key :: $(join(val.second, " -> ")) -> Any")
                else
                    println("  "^i, "$count: $key :: Any")
                end
                push!(restarts_table, key => val.second)
                count += 1
            end
            i += 1
        end
        restart = prompt("restart> ") do line
            pick = try
                parse(Int64, line)
            catch
                return nothing
            end
            @match pick begin
                0                        => ExceptionalExtended.signal("Restart canceled")
                1:length(restarts_table) => restarts_table[pick]
                _                        => println("Invalid restart")
            end
        end
        params = []
        if restart.second != nothing
            for type in restart.second
                input = @match type begin
                    Function => prompt("Input $type: () -> ") do line
                        () -> eval(Meta.parse(line))
                    end
                    _        => prompt("Input $type: ") do line
                        try
                            parse(type, line)
                        catch e
                            println("Invalid input: '$e'")
                        end
                    end
                end
                push!(params, input)
            end
        end
        invoke_restart(restart.first, params...)
    else
        Base.error("Invalid restart mode")
    end
end

Base.parse(String, x) = x

warning(msg) = println("\e[33mWARNING:\e[0m $msg")

macro fn_types(lambda::Expr)
    _fn_types(lambda)
end

function _fn_types(lambda::Expr)
    if lambda.head == :-> # nice :)
        l_args = lambda.args[1]
        types = DataType[]
        if l_args.head == :(::)
            push!(types, eval(l_args.args[2]))
        else
            for e in l_args.args
                if e isa Expr && e.head == :(::)
                    push!(types, eval(e.args[2]))
                else
                    warning("Type of '$e' not supplied, using 'String'")
                    push!(types, String)
                end
            end
        end
        if isempty(types)
            :($(esc(lambda)))
        else
            :($(esc(lambda)) => ($(types...),))
        end
    else
        Base.error("Invalid expression, must be a lambda: $(dump(lambda, maxdepth=100))")
    end
end

macro handler_case(e_try::Expr, catches...)
    if length(catches) == 1 && catches[1].head == :block
        catches = [c for c in catches[1].args]
    end
    token = gensym(:token)
    quote
        block() do $token
            Exceptional.handler_bind($([handler(c, token) for c in catches]...)) do
                $(esc(e_try))
            end
        end
    end
end

syntax_error(syntax, extra="") = Base.error("Invalid syntax, should be '$syntax'. $extra")

handler(l::LineNumberNode, _token) = l
handler(catcher::Expr, token) = begin
    error_out(extra="") = syntax_error("var::Exception = expr", extra)
    if catcher.head == :block
        for a in catcher.args
            if a isa LineNumberNode
                continue
            elseif a isa Expr && a.head == :(=)
                catcher = a
                break
            else
                error_out("Expected '=' got '$a'")
            end
        end
    elseif catcher.head != :(=)
        error_out("Expected '=' got '$(catcher.head)'")
    end
    (e_var, exception) = if isempty(catcher.args)
        error_out("Expected typed variable, got empty args")
    else
        @match typeof(catcher.args[1]) begin
            Expr => if catcher.args[1].head != :(::)
                error_out("Expected typed variable, got something else: $(catcher.args[1].head)")
            else
                catcher.args[1].args[1:2]
            end
            Symbol => catcher.args[1] => Exception
            _ => error_out("Expected 'Expr' or 'Symbol' got '$_'")
        end
    end
    expr = catcher.args[2]
    quote
        $(esc(exception)) => ($(esc(e_var))) -> Exceptional.return_from($token, $(esc(expr)))
    end
end

macro restart_case(e_try::Expr, restarts...)
    if length(restarts) == 1 && restarts[1].head == :block
        restarts = [c for c in restarts[1].args]
    end
    rs = [make_restart(r) for r in restarts if !isa(r, LineNumberNode)]
    quote
        Exceptional.restart_bind($(rs...)) do
            $(esc(e_try))
        end
    end
end

make_restart(l::LineNumberNode) = l
make_restart(restart::Expr) = begin
    error_out(extra="") = syntax_error(":name => (a, b) -> expr", extra)
    if restart.head != :call; error_out("Expected 'call' got '$(restart.head)'") end
    if restart.args[1] != :(=>); error_out("Expected '=>' got '$(restart.args[1])'") end
    name = restart.args[2]
    expr = restart.args[3]
    if expr.head == :-> && has_typed_arguments(expr.args[1])
        :($name => $(_fn_types(expr)))
    else
        :($name => $(esc(expr)))
    end
end

any(f, a) = begin
    for i in map(f, a)
        if i
            return true
        end
    end
    false
end
any(a) = any(identity, a)

has_typed_arguments(args::Symbol) = false
has_typed_arguments(args::Expr) = @match args.head begin
    :(::) => true
    :tuple => any(has_typed_arguments, args.args)
    _ => syntax_error("(a...)", "Expected lambda args, got $(args)")
end


end
