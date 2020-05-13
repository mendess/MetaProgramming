module stack

export Stack, push!, pop!, peek, length

mutable struct Stack{T}
    stack::Vector{T}

    Stack{T}() where {T} = new{T}(Vector())
end

Base.push!(s::Stack{T}, t::T) where {T} = push!(s.stack, t)

function Base.pop!(s::Stack{T})::Union{T, Nothing} where {T}
    if length(s.stack) > 0
        pop!(s.stack)
    else
        nothing
    end
end

function peek(s::Stack{T})::Union{T, Nothing} where {T}
    if length(s.stack) > 0
        last(s.stack)
    else
        nothing
    end
end

Base.length(s::Stack{T}) where {T} = length(s.stack)

function Base.iterate(s::Stack{T}) where {T}
    if length(s.stack) > 0
        peek(s) => (length(s.stack) - 1)
    else
        nothing
    end
end

function Base.iterate(s::Stack{T}, state) where {T}
    if state != 0
        s.stack[state] => (state - 1)
    else
        nothing
    end
end

end
