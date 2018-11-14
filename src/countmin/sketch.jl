"""
    CountMinSketch{T<:Unsigned}(length, ntables)

Constructs a count-min sketch for memory-friendly counting of hashable objects.
The count returned by a sketch is sometimes higher than the true count, never lower.
The CountMinSketch does not overflow, - each cell is maximally `typemax(T)`.

# Arguments
* `len`: The number of elements in each hash table
* `ntables`: Number of tables

# Examples
```julia-repl
julia> sketch = CountMinSketch(5000, 4);
julia> push!(sketch, "hello"); # increment by one
julia> add!(sketch, "hello", eltype(sketch)(5)); # increment by 5
julia> sketch["hello"]
6
```
"""
struct CountMinSketch{T<:Unsigned}
    len::Int # Cached for speed
    width::Int # Cached for speed
    matrix::Matrix{T}

    function CountMinSketch{T}(len, ntables) where {T<:Unsigned}
        if len < 1 || ntables < 2
            throw(ArgumentError("Must have len ≥ 1 ntables ≥ 2"))
        end
        return new(len, ntables, zeros(T, (Int(len), Int(ntables))))
    end
end

CountMinSketch(len, ntables) = CountMinSketch{UInt8}(len, ntables)

function Base.:(==)(x::CountMinSketch{T}, y::CountMinSketch{T}) where {T}
    if x.len != y.len || x.width != y.width
        return false
    end
    return all(i == j for (i,j) in zip(x.matrix, y.matrix))
end

Base.:(==)(x::CountMinSketch{T1}, y::CountMinSketch{T2}) where {T1, T2} = false

function Base.show(io::IO, sketch::CountMinSketch{T}) where {T}
    print(io, "CountMinSketch{$T}", size(sketch.matrix))
end

index(x, h) = reinterpret(Int, Core.Intrinsics.urem_int(h, reinterpret(UInt64, x.len))) + 1
safeadd(x::T, y::T) where {T} = ifelse(x + y ≥ x, x + y, typemax(T))

@inline function increment!(sketch::CountMinSketch{T}, h::UInt64, table::Int, count::T) where {T}
    @inbounds existing = sketch.matrix[index(sketch, h), table]
    @inbounds sketch.matrix[index(sketch, h), table] = safeadd(existing, count)
    return nothing
end

"""
    add!(sketch::CountMinSketch, val, count)

Add `count` number of `val` to the sketch. For increased speed, let `count` be
of the same type as `eltype(sketch)`.

# Examples
```julia-repl
julia> sketch = CountMinSketch(1 << 24, 4);
julia> add!(sketch, "hello", eltype(sketch)(5));
julia> sketch["hello"]
5
```
"""
function add!(sketch::CountMinSketch, x, count)
    # Do not allow negative additions or a count higher than typemax(T)
    # This will screw up saturating arithmetic and guaranteed lower bound.
    count = convert(eltype(sketch), count)
    initial = hash(x) # initial hash if it's expensive
    increment!(sketch, initial, 1, count)
    for ntable in 2:sketch.width
        h = hash(initial, reinterpret(UInt64, ntable))
        increment!(sketch, h, ntable, count)
    end
    return sketch
end

"""
    push!(sketch::CountMinSketch, val)

Add `val` to the sketch once.
# Examples
```julia-repl
julia> sketch = CountMinSketch(1 << 24, 4);
julia> push!(sketch, "hello");
julia> sketch["hello"]
1
```
"""
Base.push!(sketch::CountMinSketch, x) = add!(sketch, x, one(eltype(sketch)))

function Base.append!(sketch::CountMinSketch, iterable)
    for i in iterable
        push!(sketch, i)
    end
end

"""
    haskey(sketch::CountMinSketch)

Check if sketch[val] > 0.
"""
Base.haskey(sketch::CountMinSketch, x) = sketch[x] > 0
Base.eltype(sketch::CountMinSketch{T}) where {T} = T
Base.size(sketch::CountMinSketch) = (sketch.len, sketch.width)
Base.sizeof(sketch::CountMinSketch) = 16 + sizeof(sketch.matrix)

"""
    empty!(sketch::CountMinSketch)

Reset counts of all items to zero, returning the sketch to initial state.
"""
function Base.empty!(sketch::CountMinSketch)
    fill!(sketch.matrix, zero(eltype(sketch)))
    return sketch
end

"""
    isempty(sketch::CountMinSketch)

Check if no items have been added to the sketch.
"""
Base.isempty(sketch::CountMinSketch) = all(i == zero(eltype(sketch)) for i in sketch.matrix[:,1])

function Base.copy!(dst::CountMinSketch{T}, src::CountMinSketch{T}) where {T}
    if dst.len != src.len || dst.width != src.width
        throw(ArgumentError("Sketches must have same dimensions"))
    end
    unsafe_copyto!(dst.matrix, 1, src.matrix, 1, src.len * src.width)
    return dst
end

function Base.copy(sketch::CountMinSketch)
    newsketch = typeof(sketch)(sketch.len, sketch.width)
    return copy!(newsketch, sketch)
end

"""
    +(x::CountMinSketch, y::CountMinSketch)

Add two count-min sketches together. Will not work if `x` and `y` do not share
parameters `T`, `length` and `width`. The result will be a sketch with the summed
counts of the two input sketches.

# Examples
```
julia> x, y = CountMinSketch(1000, 4), CountMinSketch(1000, 4);

julia> add!(x, "hello", 4); add!(y, "hello", 19);

julia> z = x + y; Int(z["hello"])
23
```
"""
function Base.:+(x::CountMinSketch{T}, y::CountMinSketch{T}) where {T}
    if x.len != y.len || x.width != y.width
        throw(ArgumentError("Sketches must have same dimensions"))
    end
    summed = copy(x)
    for i in 1:(x.len * x.width)
        @inbounds summed.matrix[i] = safeadd(summed.matrix[i], y.matrix[i])
    end
    return summed
end


"""
    fprof(sketch::CountMinSketch)

Estimate the probability of miscounting an element in the sketch.
"""
function fprof(sketch::CountMinSketch)
    rate = 1
    for col in 1:x.width
        full_in_row = 0
        for row in 1:sketch.len
            full_in_row += x.matrix[row, col] > zero(eltype(sketch))
        end
        rate *= full_in_row / sketch.len
    end
    return rate
end

"""
    getindex(sketch::CountMinSketch, item)

Get the estimated count of `item`. This is never underestimated, but may be
overestimated.
"""
function Base.getindex(sketch::CountMinSketch, x)
    initial = hash(x) # initial hash if it's expensive
    @inbounds count = sketch.matrix[index(sketch, initial), 1]
    for ntable in 2:sketch.width
        h = hash(initial, reinterpret(UInt64, ntable))
        @inbounds m = sketch.matrix[index(sketch, h), ntable]
        count = min(count, m)
    end
    return count
end
