module stack

import Base: isempty, iterate, push!, pop!, length

export Stack, push!, pop!, peek, length

mutable struct Stack{T}
    stack::Vector{T}

    Stack{T}() where {T} = new{T}(Vector())
end

length(s::Stack{T}) where {T} = length(s.stack)

push!(s::Stack{T}, t::T) where {T} = push!(s.stack, t)

pop!(s::Stack{T}) where {T} = isempty(s) ? nothing : pop!(s.stack)

peek(s::Stack{T}) where {T} = isempty(s) ? nothing : last(s.stack)

isempty(s::Stack{T}) where {T} = length(s) == 0

function iterate(s::Stack{T}) where {T}
    if isempty(s)
        nothing
    else
        peek(s) => (length(s) - 1)
    end
end

function iterate(s::Stack{T}, state) where {T}
    if state != 0
        s.stack[state] => (state - 1)
    else
        nothing
    end
end

end
