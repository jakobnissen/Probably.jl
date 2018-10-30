struct BloomFilter
    len::Int
    k::Int
    data::BitArray{1}

    function BloomFilter(len, k)
        # This contraint doubles speed due to & vs % operation in `increment!`
        if len < 1 || k < 1
            throw(ArgumentError("Must have len ≥ 1 and k ≥ 1"))
        end
        bitarray =  BitArray{1}(undef, len)
        fill!(bitarray.chunks, typemin(UInt64))
        return new(len, k, bitarray)
    end
end

function Base.show(io::IO, filter::BloomFilter)
    print(io, "BloomFilter($(filter.len), $(filter.k))")
end

@inline function bitset!(filter, hashvalue)
    i = Core.Intrinsics.urem_int(hashvalue, reinterpret(UInt64, filter.len)) + 1
    @inbounds filter.data[reinterpret(Int, i)] = true
end

@inline function bitget(filter, hashvalue)
    i = Core.Intrinsics.urem_int(hashvalue, reinterpret(UInt64, filter.len)) + 1
    y = @inbounds filter.data[reinterpret(Int, i)]
    return y
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
    return ones / filter.len
end

# This is an estimate
function Base.length(filter::BloomFilter)
    estimate =  (filter.len/filter.k) * abs(log(1 - loadfactor(filter)))
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
    dst.len == src.len || throw(ArgumentError("Length of filters must be the same."))
    copyto!(dst.data.chunks, src.data.chunks)
    return dst
end

Base.copy(x::BloomFilter) = copyto!(BloomFilter(x.len, x.k), x)

function Base.union!(dst::BloomFilter, src::BloomFilter)
    dst.len == src.len || throw(ArgumentError("Length of filters must be the same."))
    dst.data.chunks .|= src.data.chunks
    return dst
end

Base.union(x::BloomFilter, y::BloomFilter) = union!(copy(x), y)

# optimal_k(m, n) = log(2)*m/n
# ϵ(k, m, n) = (1 - exp(-k*m/n))^k
# ϵ(m, n) = ϵ(optimal_k(len, m), m, n)

# BloomFilter from n_elements and errorate
# BloomFilter from memory and errorate
# BloomFilter from memory and n_elements DONE :)
