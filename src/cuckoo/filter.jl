###### Description
#
# This is an implementation of CuckooFilter
# https://www.cs.cmu.edu/~dga/papers/cuckoo-conext2014.pdf

# Differences from implementation in paper:
# 1) Number of buckets is restricted to a power-of-two. This is to ensure that
# the index-swapping is actually reciprocal, i.e otherindex(otherindex(i)) == i.
# After doing `i %= len`, this is not true unless len is a power-of-two

# 2) When failing to insert, the ejected fingerprint is saved to a special slot
# which is then compared to when inserting or searching for fingerprints.
# This guarantees no false negatives, even after failed insertions.

# 3) An object cannot appear in a this implementation of the filter more than
# once, hence it works like a set (or a Bloom filter).

# A CuckooFilter can be understood as an array of buckets, stored consecutively in
# the .data array. A bucket consists of 4 consecutive fingerprints of F bits each.
# A bucket is stores as an unsigned integer, either UInt64 or UInt128 depending on F.
# unused bits are noncoding, i.e. have no significance:

# Structure of a Bucket64{12} (i.e. where F is 12 and encoded in UInt64):
# 0x276b42f8c141c811                # bucket.data
#   XXXX                            # Noncoding bits
#       DDDCCCBBBAAA                # Fingerprints A to D (note little-endianness)
# 0x0000000000000fff                # fingermask(Bucket{F})
# 0x0000ffffffffffff                # mask(Bucket{F})
# | 811  41c  8c1  42f |            # Displayed string in terminal
#                                   # (same as fingerprints A to D)
#
# If the bucket above is stored in a filter at index 1, the .data field would begin:
# [0x11, 0xc8, 0x41, 0xc1, 0xf8, 0x42, 0x6b, 0x27 ... ]
# If a new Bucket is inserted at index 2, the noncoding bits of the bucket at index
# 1 are overwritten with the beginning of the new bucket:
# [0x11, 0xc8, 0x41, 0xc1, 0xf8, 0x42, 0xa2, 0x99 ... ]
#                                      ^^^^  ^^^^
# Because the .data field only contains integer number of bytes, and UInt128 can
# contain F=128/4=32, and F=2 leads to 100 % FPR, F must be in 3:32.

######## SmallCuckoo
#
# In a semi-sorted cuckoo filter (SmallCuckoo), the bucket is stored in an encoded
# form in the .data field. This saves 1 bit per fingerprint. To encode:
#
# 0x276b42f8c141c811             # Input bucket
# 0x00008c181142f41c             # Fingerprints sorted
# The 4 highest and F-4 lowest bits per fingerprint can be extracted:
# 0x0000000000004488             # 4 highest bits (call it H)
# 0x000000001c2f11c1             # F-4 lowest bits
# There are only 3876 possible values of 4*4 highest bits, so a value can be
# stored in 12 bits by searching for the index of PREFIXES that stores it:
# 0x00000000000009f9             # Index-1 to find highest bits
# The 12-bit index and the lowest bits are then concatenated:
# 0x000001c2f11c19f9             # Encoding of bucket (4 bits saved)
#
# To decode it, simply reverse all the steps. Because one bit is saved, F
# must be in 3:31. This whole process means the SmallCuckoo is > 2x slower.

include("bucket.jl")

# This parameter determines how long the filter will attempt to insert an item
# when it's getting full. Too low, and the filter cannot fill properly. Too high,
# and it will attempt to insert in full filters for far too long.
const MAX_KICKS = 512

abstract type AbstractCuckooFilter{F} end

"""
    FastCuckoo{F}(len::Int)

Construct a `FastCuckoo` with `F` bits per fingerprint and `len` total slots
for fingerprints. `F` must be in 4:32 and `len` a positive power-of-two.

Memory consumption is approximately 64 + `len` * `F` / 2 bytes.
"""
mutable struct FastCuckoo{F} <: AbstractCuckooFilter{F}
    nbuckets::Int64
    mask::UInt64
    ejected::UInt64 # Fingerprint ejected from filter (guarantees no false negatives)
    ejectedindex::UInt64
    data::Vector{UInt8}

    function FastCuckoo{F}(len::Int) where {F}
        if len < 4 || !ispow2(len)
            throw(ArgumentError("len must be a power-of-two, and at least 4"))
        elseif !(F isa Int) || !(3 ≤ F ≤ 32)
            throw(ArgumentError("F must be in 4:32"))
        end
        nbuckets = len >>> 2
        # Prevents unsafe_writebits! from writing off the edge of the array.
        padding = ifelse(F ≤ 16, 8, 16)
        data_array = zeros(UInt8, ((nbuckets-1)*F) >>> 1 + padding)
        mask = UInt64(nbuckets) - 1
        new(nbuckets, mask, typemin(UInt64), typemin(UInt64), data_array)
    end
end

"""
    SmallCuckoo{F}(len::Int)

Construct a `SmallCuckoo` with `F` bits per fingerprint and `len` total slots
for fingerprints. `F` must be in 3:31 and `len` a positive power-of-two.
Because of the memory-saving bucket encoding used, a `SmallCuckoo{F}` contains
`Bucket{F+1}`.

Memory consumption is approximately 64 + `len` * `F` / 2 bytes.
"""
mutable struct SmallCuckoo{F} <: AbstractCuckooFilter{F}
    nbuckets::Int64
    mask::UInt64
    ejected::UInt64 # Fingerprint ejected from filter (guarantees no false negatives)
    ejectedindex::UInt64
    data::Vector{UInt8}

    function SmallCuckoo{F}(len::Int) where {F}
        if len < 4 || !ispow2(len)
            throw(ArgumentError("len must be a power-of-two, and at least 4"))
        elseif !(F isa Int) || !(2 ≤ F ≤ 31)
            throw(ArgumentError("F must be in 3:31"))
        end
        nbuckets = len >>> 2
        # Prevents unsafe_writebits! from writing off the edge of the array.
        padding = ifelse(F ≤ 16, 8, 16)
        data_array = zeros(UInt8, ((nbuckets-1)*F) >>> 1 + padding)
        mask = UInt64(nbuckets) - 1
        new(nbuckets, mask, typemin(UInt64), typemin(UInt64), data_array)
    end
end

Base.eltype(::Type{FastCuckoo{F}}) where {F} = F ≤ 16 ? Bucket64{F} : Bucket128{F}

# Because of the encoding, one bit per fingerprint is saved in a SmallCuckoo
Base.eltype(::Type{SmallCuckoo{F}}) where {F} = F ≤ 16 ? Bucket64{F+1} : Bucket128{F+1}

function Base.show(io::IO, x::AbstractCuckooFilter{F}) where {F}
    print(io, lastindex(x), "-bucket ", typeof(x))
end

Base.summary(io::IO, x::AbstractCuckooFilter) = show(io, x)

function Base.show(io::IO, ::MIME"text/plain", x::AbstractCuckooFilter{F}) where {F}
    summary(io, x)
    println(io, ':')

    # Print it in Array-like fashion, displaying the Buckets in the filter
    if lastindex(x) < 31
        for i in eachindex(x)
            println(io, ' ', x[i])
        end
    else
        for i in 1:15
            println(io, ' ', x[i])
        end
        println(' '^(5 + 2*cld(F, 4)), '⋮')
        for i in lastindex(x)-14:lastindex(x)
            println(io, ' ', x[i])
        end
    end
end

# This means they have the same underlying data, because of the randomness in
# the kick! function, they might contain the same elements even when x != y.
# Conversely, identical filters may contain different elements due to hash collisions.
"""
    ==(x::AbstractCuckooFilter{F1}, y::AbstractCuckooFilter{F2})

First checks if F1 == F2. Then checks if the ejected fingerprints are the same.
Last checks if the underlying data arrays are equal.
Two equal filters mean they behave identically. It does not mean they have been
fed the same data.
"""
Base.:(==)(x::AbstractCuckooFilter, y::AbstractCuckooFilter) = false
function Base.:(==)(x::AbstractCuckooFilter{F}, y::AbstractCuckooFilter{F}) where {F}
    return x.ejected == y.ejected && x.ejectedindex == y.ejectedindex && x.data == y.data
end

function Base.hash(x::AbstractCuckooFilter, y::UInt64=typemin(UInt64))
    hash((x.data, x.ejected, x.ejectedindex), y)
end

"""
    isempty(x::AbstractCuckooFilter)

Test if the filter contains no elements. Guaranteed to be correct.

# Examples
```
julia> a = FastCuckoo{12}(1<<12); isempty(a)
true
```
"""
Base.isempty(x::AbstractCuckooFilter) = all(i == 0x00 for i in x.data)

"""
    empty!(x::AbstractCuckooFilter)

Removes all objects from the cuckoo filter, resetting it to initial state.

# Examples
```
julia> a = FastCuckoo{12}(1<<12); push!(a, "Hello"); isempty(a)
false

julia> empty!(a); isempty(a)
true
```
"""
function Base.empty!(x::AbstractCuckooFilter)
    x.ejected = typemin(UInt64)
    x.ejectedindex = typemin(UInt64)
    fill!(x.data, 0x00)
    return x
end

function Base.copy!(dst::AbstractCuckooFilter{F}, src::AbstractCuckooFilter{F}) where {F}
    lastindex(dst) != lastindex(src) && throw(ArgumentError("Must have same len."))
    copyto!(dst.data, src.data)
    dst.ejected = src.ejected
    dst.ejectedindex = src.ejectedindex
    return dst
end
Base.copy(x::AbstractCuckooFilter) = copy!(typeof(x)(x.nbuckets << 2), x)

# This measures how full the filter is.
"""
    loadfactor(x::AbstractCuckooFilter)

Returns fraction of filled fingerprint slots, i.e. how full the filter is.

# Examples
```
julia> a = FastCuckoo{12}(1<<12);
julia> for i in 1:1<<11 push!(i, a) end; loadfactor(a)
0.5
```
"""
function loadfactor(x::AbstractCuckooFilter)
    full_fields = 0
    for i in eachindex(x)
        bucket = unsafe_getindex(x, i)
        for fingerprint in bucket
            full_fields += 1
        end
    end
    return full_fields / (lastindex(x) * 4)
end

Base.firstindex(x::AbstractCuckooFilter) = 1
Base.lastindex(x::AbstractCuckooFilter) = x.nbuckets
Base.eachindex(x::AbstractCuckooFilter) = Base.OneTo(lastindex(x))

# Important here only that it's dependent on `val` and inbounds
function primaryindex(filter::AbstractCuckooFilter, val)
    return hash(val) & filter.mask + 1
end

# Should be depedent on i and fingerprint and be inbounds. Furthermore, must
# always hold that otherindex(x, otherindex(x, i, f), f) == i.
# It's this latter property that constrains filters to having power-of-two len.
function otherindex(filter::AbstractCuckooFilter, i::UInt64, fingerprint)
    return ((i - 1) ⊻ hash(fingerprint)) & filter.mask + 1
end

valof(::Val{x}) where {x} = x

# This reads the i'th chunk of bits each of size nbits from array into a T.
# E.g. unsafe_readbits(A, UInt64, Val(11), 3) reads the 23:86rd bits of A to a UInt64
function unsafe_readbits(array::Array{UInt8}, T::Type{<:Unsigned}, v::Val, i)
    nbits = valof(v)
    bitoffset = (i-1)*nbits
    byteoffset = bitoffset >>> 3
    data = unsafe_load(Ptr{T}(pointer(array, byteoffset + 1)), 1)
    data >>>= bitoffset & 7
    return data
end

function unsafe_getindex(x::FastCuckoo{F}, i) where {F}
    # A Bucket{F} contains 4F bits
    return eltype(x)(unsafe_readbits(x.data, eltype(eltype(x)), Val(4F), i))
end

function unsafe_getindex(x::SmallCuckoo{F}, i) where {F}
    # A Bucket{F+1} is encoded in 4F bits
    return decode(unsafe_readbits(x.data, eltype(eltype(x)), Val(4F), i), eltype(x))
end

# Writes the first nbits of val to the ith chunk of bits nbits in size in array
# E.g. unsafe_writebits!(A, UInt64, Val(11), 3, typemax(UInt64))
# writes exactly 11 ones to the 23:33rd bits of A
function unsafe_writebits!(array::Array{UInt8}, T::Type{<:Unsigned}, v::Val, i, val)
    nbits = valof(v)
    bitoffset = (i-1)*nbits
    byteoffset = bitoffset >>> 3
    p = Ptr{T}(pointer(array, byteoffset + 1))
    # We overwrite the unused bits of val with bits from array in order to
    # not overwrite array with unsused bits from val that are different
    data = unsafe_load(p, 1)
    bitshift = bitoffset & 7
    bitmask = (T(1) << nbits - T(1)) << bitshift
    data &= ~bitmask
    data |= bitmask & (val << bitshift)
    unsafe_store!(p, data, 1)
end

function unsafe_setindex!(x::FastCuckoo{F}, val::AbstractBucket{F}, i) where {F}
    unsafe_writebits!(x.data, eltype(eltype(x)), Val(4F), i, val.data)
end

function unsafe_setindex!(x::SmallCuckoo{F1}, val::AbstractBucket{F2}, i) where {F1, F2}
    F1 + 1 == F2 || throw(ArgumentError("Filter/bucket F parameter mismatch"))
    unsafe_writebits!(x.data, eltype(eltype(x)), Val(4F1), i, encode(val))
end

function Base.checkbounds(x::AbstractCuckooFilter, i)
    (i < 1 || i > lastindex(x)) && throw(BoundsError(x, i))
end

function Base.getindex(x::AbstractCuckooFilter, i)
    @boundscheck checkbounds(x, i)
    unsafe_getindex(x, i)
end

function Base.setindex!(x::AbstractCuckooFilter, val::AbstractBucket, i)
    @boundscheck checkbounds(x, i)
    unsafe_setindex!(x, val, i)
end

# Puts a fingerprint into a Bucket at index `i` in filter.
function putinfilter!(x::AbstractCuckooFilter, i, fingerprint)
    bucket = unsafe_getindex(x, i)
    newbucket, success = putinbucket!(bucket, fingerprint)
    if success
        unsafe_setindex!(x, newbucket, i)
    end
    return success
end

# Forcibly put a fingerprint into a bucket at index `i` in filter.
# returns the fingerprint ejected to make room
function kick!(x::AbstractCuckooFilter, i, fingerprint, bucketindex::Int)
    bucket = unsafe_getindex(x, i)
    newbucket, newfingerprint = kick!(bucket, fingerprint, bucketindex)
    unsafe_setindex!(x, newbucket, i)
    return newfingerprint
end

function pushfingerprint(filter::AbstractCuckooFilter, fingerprint, index)
    # If filter is closed, don't even attempt to insert it.
    if filter.ejected != typemin(eltype(eltype(filter)))
        return fingerprint == filter.ejected
    end

    # Attempt to push fingerprint to primary index
    success = putinfilter!(filter, index, fingerprint)
    if success
        return nothing
    end

    # Kick the fingerprint around until we find an empty spot, or MAX_KICKS has
    # occurred - we don't want it to loop for literally ever.
    for kicks in 1:MAX_KICKS
        index = otherindex(filter, index, fingerprint)
        success = putinfilter!(filter, index, fingerprint)
        if success
            return nothing
        end
        # Replace fingerprint with ejected fingerprint
        fingerprint = kick!(filter, index, fingerprint, rand(1:4))
    end

    filter.ejected = fingerprint
    filter.ejectedindex = index
    return nothing
end

"""
    push!(filter::AbstractCuckooFilter, items...)

Insert one or more items into the cuckoo filter. Returns `true` if all inserts
was successful and `false` otherwise.
"""
function Base.push!(filter::AbstractCuckooFilter, x)
    fingerprint = imprint(x, eltype(filter))
    index = primaryindex(filter, x)
    return pushfingerprint(filter, fingerprint, index)
end

function Base.push!(filter::AbstractCuckooFilter, x...)
    success = true
    for i in x
        success &= push!(filter, i)
    end
    return success
end


"""
    in(item, filter::AbstractCuckooFilter)

Check if an item is in the cuckoo filter. This can sometimes erroneously return
`true`, but never erroneously returns `false`, unless a `pop!` operation has been
performed on the filter.
"""
function Base.in(x, filter::AbstractCuckooFilter{F}) where {F}
    fingerprint = imprint(x, eltype(filter))
    # First check the ejected slot...
    if fingerprint == filter.ejected
        return true
    end
    # ... then the primary bucket ...
    first_index = primaryindex(filter, x)
    bucket = unsafe_getindex(filter, first_index)
    if fingerprint in bucket
        return true
    # Finally, check the last possible place, the alternate bucket
    else
        alternate_index = otherindex(filter, first_index, fingerprint)
        bucket = unsafe_getindex(filter, alternate_index)
        return fingerprint in bucket
    end
end


"""
    pop!(filter::AbstractCuckooFilter, item)

Delete an item from the cuckoo filter, returning the filter. Does not throw an
error if the item does not exist. Has a risk of deleting other items if they
collide with the target item in the filter.

# Examples
```
julia> a = FastCuckoo{12}(2^4); push!(a, 1); push!(a, 868)
julia> pop!(a, 1); # Remove 1, this accidentally deletes 868 also
julia> isempty(a)
true
```
"""
function Base.pop!(filter::AbstractCuckooFilter{F}, key) where {F}
    # Remove from the two possible buckets it could be in.
    fingerprint = imprint(key, eltype(filter))
    index1 = primaryindex(filter, key)
    index2 = otherindex(filter, index1, fingerprint)
    unsafe_setindex!(filter, pop!(unsafe_getindex(filter, index1), fingerprint), index1)
    unsafe_setindex!(filter, pop!(unsafe_getindex(filter, index2), fingerprint), index2)

    # Having deleted an object, we can "open" a closed filter
    # by pushing the ejected value back into the buckets and zeroing the ejected
    if filter.ejected != typemin(UInt64)
        sucess = pushfingerprint(filter, filter.ejected, filter.ejectedindex)
        if sucess
            filter.ejected = typemin(UInt64)
            filter.ejectedindex = typemin(UInt64)
        end
    end
    return filter
end

"""
    union!(dst::AbstractCuckooFilter{F}, src::AbstractCuckooFilter{F})

Attempt to add all elements of source filter to destination filter. If destination
runs out of space, abort the copying and return `(destination, false`). Else, return
`(destination, true)`.
Both filters must have the same length and F value.
"""
function Base.union!(dst::AbstractCuckooFilter{F}, src::AbstractCuckooFilter{F}) where {F}
    dst.nbuckets != src.nbuckets && throw(ArgumentError("Must have same length."))
    for index in 1:lastindex(dst)
        dstbucket = unsafe_getindex(dst, index)
        srcbucket = unsafe_getindex(src, index)
        # If destination bucket is empty, we copy entire source bucket
        if isempty(dstbucket)
            unsafe_setindex!(dst, srcbucket, index)
        # Else we just insert each nonzero fingerprint from the bucket
        else
            for fingerprint in srcbucket # this skips empty fingerprints
                pushfingerprint(dst, fingerprint, index)
                if dst.ejected != typemin(UInt64)
                    return (dst, false)
                end
            end
        end
    end
    return (dst, true)
end

"""
    union(x::AbstractCuckooFilter{F}, y::AbstractCuckooFilter{F})

Attempt to create a new cuckoo fitler with the same length and F value as x and y,
and with the union of their elements. If the new array does not have enough space,
returns `(newfilter, false)`, else returns `(newfilter, true)`.
Both filters must have the same length and F value.
"""
function Base.union(x::AbstractCuckooFilter{F}, y::AbstractCuckooFilter{F}) where {F}
    x.nbuckets != y.nbuckets && throw(ArgumentError("Must have same length."))
    return union!(copy(x), y)
end

"""
    sizeof(filter::AbstractCuckooFilter)

Get the total RAM use of the cuckoo filter, including the underlying array.
"""
Base.sizeof(x::AbstractCuckooFilter) = 32 + sizeof(x.data)

# The 0.95 constant is approximately how full a filter can be given MAX_KICKS = 512
# Perhaps a little conservative but that's okay
"""
    capacityof(filter::AbstractCuckooFilter)

Estimate the number of distinct elements that can be pushed to the filter before
adding more will fail. Since push failures are probabilistic, this is not accurate,
but for filters with a capacity of thousands or more, this is rarely more than 1% off.
"""
capacityof(x::AbstractCuckooFilter) = round(Int, 0.95 * 4 * x.nbuckets, RoundUp)

# Probability of false positives given a completely full filter.
"""
    fprof(::Type{AbstractCuckooFilter{F}}) where {F}
    fprof(x::AbstractCuckooFilter)

Get the false positive rate for a fully filled AbstractCuckooFilter{F}.
The FPR is proportional to the fullness (a.k.a load factor).
"""
function fprof(T::Type{<:AbstractCuckooFilter{FF}}) where {FF}
    F = BucketF(eltype(T))
    prob_avoid_ejected = (2^F-2) / (2^F-1)
    # The reason this is not ((2^F-1)/(2^F-2))^4 is because each fingerprint
    # is guaranteed to be unique in that bucket.
    prob_avoid_bucket = prod((2^F - 1 - i) / (2^F - i) for i in 1:4)
    return 1 - prob_avoid_ejected * prob_avoid_bucket * prob_avoid_bucket
end

fprof(x::AbstractCuckooFilter) = fprof(typeof(x))

# Minimal F given a false positive rate
function minimal_f(T::Type{<:AbstractCuckooFilter}, fpr)
    for F in 4:33
        if fprof(T{F}) < fpr
            minF, maxF = ifelse(T === FastCuckoo, (4, 32), (3, 31))
            F = max(F, minF)
            if F > maxF
                throw(ArgumentError("Too low FPR"))
            end
            return F
        end
    end
end

function stats(T::Type{<:AbstractCuckooFilter{F}}, nfingerprints) where {F}
    fpr = fprof(T)
    nbuckets = nfingerprints >>> 2
    mem = 42 + (((nbuckets)-1)*F) >>> 1 + sizeof(eltype(T))
    capacity = round(Int, nfingerprints * 0.95, RoundUp)
    return (F=F, nfingerprints=nfingerprints, fpr=fpr, memory=mem, capacity=capacity)
end

# Largest filter that's smaller than `mem` and with lower fpr than `fpr`
function mem_fpr(T::Type{<:AbstractCuckooFilter}, mem, fpr)
    F = minimal_f(T, fpr)
    mem -= 42 + 16 # constant overhead
    nfingerprints = prevpow(2, 8*mem / F)
    if nfingerprints < 4
        throw(ArgumentError("Too little memory"))
    end
    return stats(T{F}, nfingerprints)
end

# Smallest filter that can hold `elements` elements with fpr lower than `fpr`
function capacity_fpr(T::Type{<:AbstractCuckooFilter}, capacity, fpr)
    F = minimal_f(T, fpr)
    nfingerprints = max(4, nextpow(2, capacity / 0.95))
    return stats(T{F}, nfingerprints)
end

# Largest filter that can hold `capacity` capacity, and smaller than `mem`
function mem_capacity(T::Type{<:AbstractCuckooFilter}, mem, capacity)
    nfingerprints = max(4, nextpow(2, capacity / 0.95))
    mem -= 42 + 16 # constant overhead
    F = round(Int, 8 * mem / nfingerprints, RoundUp)
    minF, maxF = ifelse(T === FastCuckoo, (4, 32), (5, 31))
    F = min(F, maxF)
    if F < minF
        throw(ArgumentError("Too little memory"))
    end
    return stats(T{F}, nfingerprints)
end

"""
    constrain(T<:AbstractCuckooFilter; fpr=nothing, mem=nothing, capacity=nothing)

Given a subtype of `AbstractCuckooFilter` and two of three keyword arguments,
as constrains, optimize the elided keyword argument.
Returns a NamedTuple with (F, nfingerprints, fpr, memory, capacity), which applies
to an instance of the optimized CuckooFilter.

# Examples
```
julia> # FastCuckoo with FPR ≤ 0.001, and memory usage ≤ 250_000_000 bytes

julia> c = constrain(FastCuckoo, fpr=0.001, memory=250_000_000)
(F = 14, nfingerprints = 134217728, fpr = 0.0005492605216655955, memory = 234881081,
capacity = 127506842)

julia> x = FastCuckoo{c.F}(c.nfingerprints); # capacity optimized

julia> fprof(x), sizeof(x), capacityof(x) # not always exactly the estimate
(0.0005492605216655955, 234881081, 127506842)
```
"""
function constrain(T::Type{<:AbstractCuckooFilter}; fpr=nothing, memory=nothing, capacity=nothing)
    if (fpr===nothing) + (memory===nothing) + (capacity===nothing) != 1
        throw(ArgumentError("Exactly one argument must be nothing"))
    elseif fpr !== nothing && fpr ≤ 0
        throw(ArgumentError("FPR must be above 0"))
    elseif memory !== nothing && memory ≤ 64
        throw(ArgumentError("Memory must be above 64"))
    end
    if fpr === nothing
        return mem_capacity(T, memory, capacity)
    elseif memory === nothing
        return capacity_fpr(T, capacity, fpr)
    else
        return mem_fpr(T, memory, fpr)
    end
end
