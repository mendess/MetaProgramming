# Failures of the language

The `isa` operator is not well implemented enough

```julia
julia> (1 => 2) isa Pair
true
julia> (1 => 2 => 3) isa Pair
true
julia> (1 => 2 => 3) isa Pair{Int64, Pair}
false
julia> (1 => 2 => 3) isa Pair{Int64, Pair{Int64, Int64}}
true
```

> Why is this a problem? Can't I just specify all the type parameters?

No, because there is another problem with `isa`.

```julia
julia> foo = 1 => ((() -> println()) => 2)
julia> typeof(foo)
Pair{Int64,Pair{var"#27#28",Int64}}
julia> foo isa Pair
true
julia> foo isa Pair{Int, Pair}
false
julia> foo isa Pair{Int, Pair{Function, Int}}
false
julia> foo isa Pair{Int, Pair{Any, Int}}
false
```
