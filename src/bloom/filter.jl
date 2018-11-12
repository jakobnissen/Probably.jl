struct BloomFilter
    k::Int
    data::BitArray{1}

    function BloomFilter(len, k)
        if len < 1 || k < 1
            throw(ArgumentError("Must have len ≥ 1 and k ≥ 1"))
        end
        bitarray =  BitArray{1}(undef, len)
        fill!(bitarray.chunks, typemin(UInt64))
        return new(k, bitarray)
    end
end

Base.sizeof(x::BloomFilter) = 24 + sizeof(x.data)

function Base.summary(io::IO, filter::BloomFilter)
    print(io, "BloomFilter($(length(filter.data)), k=$(filter.k))")
end

function Base.:(==)(x::BloomFilter, y::BloomFilter)
    if x.k != y.k || length(x.data) != length(y.data)
        return false
    end
    return all(i == j for (i, j) in zip(x.data.chunks, y.data.chunks))
end

Base.show(io::IO, filter::BloomFilter) = summary(io, filter)

@inline function bitset!(filter, hashvalue)
    i = Core.Intrinsics.urem_int(hashvalue, reinterpret(UInt64, length(filter.data))) + 1
    @inbounds filter.data[reinterpret(Int, i)] = true
end

@inline function bitget(filter, hashvalue)
    i = Core.Intrinsics.urem_int(hashvalue, reinterpret(UInt64, length(filter.data))) + 1
    return @inbounds filter.data[reinterpret(Int, i)]
end

function Base.push!(filter::BloomFilter, x)
    initial = hash(x) # initial hash if it's expensive
    bitset!(filter, initial)
    for ntable in 2:filter.k
        h = hash(initial, reinterpret(UInt64, ntable))
        bitset!(filter, h)
    end
    return x
end

"""
    push!(filter::BloomFilter, items...)

Add one or more hashable items to the bloom filter.
"""
function Base.push!(filter::BloomFilter, x...)
    for i in x
        push!(filter, i)
    end
end

"""
    in(item, filter::BloomFilter)

Determine if item is in bloom filter. This sometimes returns `true` when the correct
answer is `false`, but never returns `false` when the correct answer is `true`.
"""
function Base.in(x, filter::BloomFilter)
    initial = hash(x) # initial hash if it's expensive
    y = bitget(filter, initial)
    y == false && return false
    for ntable in 2:filter.k
        h = hash(initial, reinterpret(UInt64, ntable))
        y = bitget(filter, h)
        y == false && return false
    end
    return true
end

function loadfactor(filter::BloomFilter)
    ones = sum(count_ones(i) for i in filter.data.chunks)
    return ones / length(filter.data)
end

"""
    length(filter::BloomFilter) -> Float64

Provide an *estimate* of the number of distinct elements in the filter. This
may return `Inf` if the filter is entirely full.

# Examples
```
julia> a = BloomFilter(10000, 4); for i in 1:5000 push!(a, i) end; length(a)
4962.147247984721
```
"""
function Base.length(filter::BloomFilter)
    return (length(filter.data)/filter.k) * abs(log(1 - loadfactor(filter)))
end

"""
    isempty(filter::BloomFilter)

Determine if bloom filter is empty, i.e. has no elements in it.
This is guaranteed to be correct, but does not mean the fitler consumes no RAM.
"""
function Base.isempty(filter::BloomFilter)
    return all(i == typemin(UInt64) for i in filter.data.chunks)
end

"""
    empty!(filter::BloomFilter)

Remove all elements from BloomFilter, resetting it to initial state.
"""
function Base.empty!(filter::BloomFilter)
    fill!(filter.data.chunks, typemin(UInt64))
    return filter
end

function Base.copy!(dst::BloomFilter, src::BloomFilter)
    if length(dst.data) != length(src.data) || dst.k != src.k
        throw(ArgumentError("Length of filters must be the same."))
    end
    copyto!(dst.data.chunks, src.data.chunks)
    return dst
end

Base.copy(x::BloomFilter) = copy!(BloomFilter(length(x.data), x.k), x)

function Base.union!(dst::BloomFilter, src::BloomFilter)
    if length(dst.data) != length(src.data)
        throw(ArgumentError("Length of filters must be the same."))
    end
    dst.data.chunks .|= src.data.chunks
    return dst
end

Base.union(x::BloomFilter, y::BloomFilter) = union!(copy(x), y)

function mem_fpr(::Type{BloomFilter}, mem, fpr)
    mem -= (mem - 24) % 8 # nearest UInt64
    m = 8 * (mem - 24) # bytes to bits
    m < 64 && throw(ArgumentError("Too little memory"))
    n = round(Int, -log(2)*log(2)*m/log(fpr), RoundDown) # approximate n
    k = round(Int, log(2)*m/n) # optimize k with n and m
    _fpr = (1 - exp(-k*n/m))^k
    while _fpr > fpr # Now fine-tune n
        n -= 10
        n < 1 && throw(ArgumentError("Too little memory"))
        _fpr = (1 - exp(-k*n/m))^k
    end
    return (m=m, k=k, fpr=_fpr, memory=mem, capacity=n)
end

function capacity_fpr(::Type{BloomFilter}, capacity, fpr)
    n = capacity # approximate n
    m = round(Int, capacity * log(fpr) / (-log(2) * log(2)), RoundUp)
    m += 64 - m % 64 # nearest UInt64
    mem = 24 + (m >>> 3) # bits to bytes
    k = round(Int, log(2)*m/capacity)
    _fpr = (1 - exp(-k*n/m))^k
    while _fpr > fpr # Fine-tune m
        m += 64
        mem += 8
        _fpr = (1 - exp(-k*n/m))^k
    end
    return (m=m, k=k, fpr=_fpr, memory=mem, capacity=n)
end

function mem_capacity(::Type{BloomFilter}, mem, capacity)
    n = capacity # approximate n
    mem -= mem % 8
    m = 8 * (mem - 24) # bytes to bits
    m < 64 && throw(ArgumentError("Too little memory"))
    k = round(Int, log(2)*m/capacity)
    fpr = (1 - exp(-k*n/m))^k
    return (m=m, k=k, fpr=fpr, memory=mem, capacity=n)
end

"""
    constrain(Type{BloomFilter}; fpr=nothing, mem=nothing, capacity=nothing)

Given BloomFilter and two of three keyword arguments, as constrains,
optimize the elided keyword argument.
Returns a NamedTuple with (m, k, fpr, memory, capacity), which applies to the
optimized Bloom filter.

# Examples
```
julia> # Bloom filter with FPR ≤ 0.05, and memory usage ≤ 50_000_000 bytes

julia> c = constrain(BloomFilter, fpr=0.05, memory=50_000_000)
(m = 399999808, k = 4, fpr = 0.049999979847949585, memory = 50000000, capacity = 6403092
1)

julia> x = BloomFilter(c.m, c.k); # capacity optimized
```
"""
function constrain(::Type{BloomFilter}; fpr=nothing, memory=nothing, capacity=nothing)
    if (fpr===nothing) + (memory===nothing) + (capacity===nothing) != 1
        throw(ArgumentError("Exactly one argument must be nothing"))
    elseif fpr !== nothing && fpr ≤ 0
        throw(ArgumentError("FPR must be above 0"))
    elseif memory !== nothing && memory ≤ 64
        throw(ArgumentError("Memory must be above 30"))
    end
    if fpr === nothing
        return mem_capacity(BloomFilter, memory, capacity)
    elseif memory === nothing
        return capacity_fpr(BloomFilter, capacity, fpr)
    else
        return mem_fpr(BloomFilter, memory, fpr)
    end
end
