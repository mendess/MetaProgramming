"""
# Stack

This module exposes a stack with simple push and pop operations as well as peek
"""
module stack

import Base: isempty, iterate, push!, pop!, length

export Stack, push!, pop!, peek, length


@doc raw"""
A stack of elements of type T
---
```
Stack{T}()
```
Construct an empty stack
"""
mutable struct Stack{T}
    stack::Vector{T}

    Stack{T}() where {T} = new{T}(Vector())
end

length(s::Stack{T}) where {T} = length(s.stack)

@doc raw"""
Adds an item to the top of the stack.
# Example
```
s = Stack()
push!(s, 1)
@assert length(s) == 1
```
"""
push!(s::Stack{T}, t::T) where {T} = push!(s.stack, t)

@doc raw"""
Removes and returns the top item of the stack. Returns nothing if the stack is empty.
# Example
```
s = Stack()
push!(s, 1)
@assert pop!(s) == 1
@assert pop!(s) == nothing
```
"""
pop!(s::Stack{T}) where {T} = isempty(s) ? nothing : pop!(s.stack)

@doc raw"""
Returns the top item of the stack without poping it.
# Example
```
s = Stack()
push!(s, 1)
@assert peek(s) == 1
@assert peek(s) == 1
```
"""
peek(s::Stack{T}) where {T} = isempty(s) ? nothing : last(s.stack)

@doc raw"""
Checks where the stack is empty
# Example
```
s = Stack()
@assert isempty(s)
push!(s, 1)
@assert !isempty(s)
```
"""
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
