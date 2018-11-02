struct BloomFilter
    k::Int
    data::BitArray{1}

    function BloomFilter(len, k)
        # This contraint doubles speed due to & vs % operation in `increment!`
        if len < 1 || k < 1
            throw(ArgumentError("Must have len ≥ 1 and k ≥ 1"))
        end
        bitarray =  BitArray{1}(undef, len)
        fill!(bitarray.chunks, typemin(UInt64))
        return new(k, bitarray)
    end
end

function Base.summary(io::IO, filter::BloomFilter)
    print(io, "BloomFilter($(length(filter.data)), k=$(filter.k))")
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

# This is an estimate
function Base.length(filter::BloomFilter)
    estimate =  (length(filter.data)/filter.k) * abs(log(1 - loadfactor(filter)))
    return trunc(Int, estimate)
end

function Base.isempty(filter::BloomFilter)
    return all(i == typemin(UInt64) for i in filter.data.chunks)
end

function Base.empty!(filter::BloomFilter)
    fill!(filter.data.chunks, typemin(UInt64))
    return filter
end

function Base.copy!(dst::BloomFilter, src::BloomFilter)
    if length(dst.data) != length(src.data)
        throw(ArgumentError("Length of filters must be the same."))
    end
    copyto!(dst.data.chunks, src.data.chunks)
    return dst
end

Base.copy(x::BloomFilter) = copyto!(BloomFilter(length(x.data), x.k), x)

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
