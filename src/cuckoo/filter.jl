###### Description
#
# This is an implementation of CuckooFilter
# https://www.cs.cmu.edu/~dga/papers/cuckoo-conext2014.pdf

# Differences from implementation in paper:
# 1) Number of buckets is restricted to a power-of-two. This is to ensure that
# the index-swapping is actually reciprocal, i.e that swap(swap(i)) == i.
# After doing `i %= len`, this is not true unless len is a power-of-two

# 2) When failing to insert, the ejected fingerprint is saved to a special slot
# which is then compared to when inserting or searching for fingerprints.
# This guarantees no false negatives, even after failed insertions.

# 3) An object cannot appear in a filter more than once, like a set.

# A CuckooFilter can be understood as an array of buckets, stored consecutively in
# the .data field. Each bucket consists of 4 consecutive fingerprints of F bits each.
# A bucket is put in an UInt128 - unused bits are noncoding, i.e. have no significance:
#
# Structure of a Bucket{F} with F == 12 (12*4/8 bytes = 6 bytes):
# 0x26de0240554b61fd276b42f8c141c811
#   XXXXXXXXXXXXXXXXXXXX                            # Noncoding bits
#                       DDDCCCBBBAAA                # Fingerprints A to D
# 0x00000000000000000000000000000fff                # fingermask(Bucket{F})
# 0x00000000000000000000ffffffffffff                # mask(Bucket{F})
# | 811  41c  8c1  42f |                            # Displayed string in terminal
#                                                   #(same as fingerprints A to D)
#
# If the bucket above is stored in a filter at index 1, the .data field would begin:
# [0x11, 0xc8, 0x41, 0xc1, 0xf8, 0x42, 0x6b, 0x27, 0xfd ... ]
# If a new Bucket is inserted at index 2, the noncoding bits are overwritten with
# the beginning of the new bucket:
# [0x11, 0xc8, 0x41, 0xc1, 0xf8, 0x42, 0xa2, 0x99, 0x5e ... ]
#                                      ^^^^  ^^^^  ^^^^
# Because the .data field only contains integer number of bytes, and UInt128 can
# contain F=128/4=32, and F=2 leads to 100 % FPR, F must be in 4:2:32.

######## SmallCuckoo
#
# In a semi-sorted cuckoo filter (SmallCuckoo), the bucket is stored in an encoded form
# in the .data field. This saves 1 bit per fingerprint. To encode:
#
# 0x26de0240554b61fd276b42f8c141c811             # Input bucket
# 0x000000000000000000008c181142f41c             # Fingerprints sorted
# The 4 highest and F-4 lowest bits per fingerprint can be extracted:
# 0x00000000000000000000000000004488             # 4 highest bits (call it H)
# 0x0000000000000000000000001c2f11c1             # F-4 lowest bits
# There are only 3876 possible values of 4*4 highest bits, so a value can be
# stored in 12 bits by searching for the index of PREFIXES that stores it:
# 0x000000000000000000000000000009f9             # Index-1 to find highest bits
# The 12-bit index and the lowest bits are then concatenated:
# 0x0000000000000000000001c2f11c19f9             # Encoding of bucket (4 bits saved)
#
# To decode it, simply reverse all the steps. Because one bit is saved, F
# must be in 5:2:31. This whole process means the SmallCuckoo is > 2x slower.

# To do:
# Add tests

# Make a function that takes bytes, fpr, capacity and returns:
# One of them are nothing. Then infer the minimal CuckooFilter C that fits those
# constrains, and return
# sizeof(C), fpr(C), capacity(C), F of C, C.len.
# without instantiating the CuckooFilter

include("bucket.jl")

# This simply creates a "new" hash function to create fingerprints.
const FINGERPRINT_SALT = 0x7afb47f99881a598

# This parameter determines how long the filter will attempt to insert an item
# when it's getting full. Too low, and the filter cannot fill properly. Too high,
# and it will attempt to insert in full filters for far too long.
const MAX_KICKS = 512

abstract type AbstractCuckooFilter{F} end

mutable struct FastCuckoo{F} <: AbstractCuckooFilter{F}
    nbuckets::Int64
    mask::UInt64
    ejected::UInt128 # Fingerprint ejected from filter (guarantees no false negatives)
    ejectedindex::UInt64
    data::Vector{UInt8}

    function FastCuckoo{F}(len::Int) where {F}
        if len < 4 || !ispow2(len)
            throw(ArgumentError("len must be a power-of-two, and at least 4"))
        elseif !(F isa Int) || !(4 ≤ F ≤ 32) || (F & 1) == 1
            throw(ArgumentError("F must be in 4:2:32"))
        end
        # Padding is to avoid segfaulting when reading/writing Buckets off the edge
        # since we always read 128 bits, even if bucketsize(filter) is less
        nbuckets = len >> 2
        padding = sizeof(Bucket) - bucketsize(FastCuckoo{F})
        data_array = zeros(UInt8, bucketsize(FastCuckoo{F}) * nbuckets + padding)
        mask = UInt64(nbuckets) - 1
        new(nbuckets, mask, typemin(UInt128), typemin(UInt64), data_array)
    end
end

mutable struct SmallCuckoo{F} <: AbstractCuckooFilter{F}
    nbuckets::Int64
    mask::UInt64
    ejected::UInt128 # Fingerprint ejected from filter (guarantees no false negatives)
    ejectedindex::UInt64
    data::Vector{UInt8}

    function SmallCuckoo{F}(len::Int) where {F}
        if len < 4 || !ispow2(len)
            throw(ArgumentError("len must be a power-of-two, and at least 4"))
        elseif !(F isa Int) || !(5 ≤ F ≤ 31) || (F & 1) == 0
            throw(ArgumentError("F must be in 5:2:31"))
        end
        nbuckets = len >> 2
        padding = sizeof(Bucket) - bucketsize(SmallCuckoo{F})
        data_array = zeros(UInt8, bucketsize(SmallCuckoo{F}) * nbuckets + padding)
        mask = UInt64(len) - 1
        new(nbuckets, mask, typemin(UInt128), typemin(UInt64), data_array)
    end
end

# Minimal F given a false positive rate
function minimal_f(T::Type{<:AbstractCuckooFilter}, fpr)
    for F in 4:33
        if fprof(AbstractCuckooFilter{F}) < fpr
            F += ifelse(T === FastCuckoo, isodd(F), iseven(F))
            F = ifelse(T === FastCuckoo, max(4, F), max(5, F))
            maxF = ifelse(T === FastCuckoo, 32, 31)
            if F > maxF
                throw(ArgumentError("Too low FPR"))
            end
            return F
        end
    end
end

# Largest filter that's smaller than `mem` and with lower fpr than `fpr`
function mem_fpr(T::Type{<:AbstractCuckooFilter}, mem, fpr)
    F = minimal_f(T, fpr)
    nbuckets = (mem - 48) / bucketsize(AbstractCuckooFilter{F})
    nfingerprints = prevpow(2, 4 * nbuckets)
    if nfingerprints < 4
        throw(ArgumentError("Too little memory"))
    end
    return T{F}(nfingerprints)
end

# Smallest filter that can hold `elements` elements with fpr lower than `fpr`
function elements_fpr(T::Type{<:AbstractCuckooFilter}, capacity, fpr)
    F = minimal_f(T, fpr)
    nfingerprints = max(4, nextpow(2, capacity / 0.95))
    return T{F}(nfingerprints)
end

# Largest filter that can hold `capacity` capacity, and smaller than `mem`
function mem_capacity(T::Type{<:AbstractCuckooFilter}, mem, capacity)
    nfingerprints = max(4, nextpow(2, capacity / 0.95))
    nbuckets = nfingerprints >> 2
    maxbucketsize = round(Int, mem / nbuckets)
    F = maxbucketsize << 1
    F += ifelse(T === FastCuckoo, isodd(F), iseven(F))
    minF, maxF = ifelse(T === FastCuckoo, (4, 32), (5, 31))
    if F < minF
        throw(ArgumentError("Too little memory"))
    end
    F = min(F, maxF)
    return T{F}(nfingerprints)
end

function makefilter(T::Type{<:AbstractCuckooFilter}, fpr, mem, capacity)
    if (fpr===nothing) + (mem===nothing) + (capacity===nothing) != 1
        throw(ArgumentError("Exactly one argument must be nothing"))
    elseif fpr !== nothing && fpr ≤ 0
        throw(ArgumentError("FPR must be above 0"))
    elseif mem !== nothing && mem ≤ 64
        throw(ArgumentError("Memory must be above 64"))
    end
    if fpr === nothing
        return mem_capacity(T, mem, capacity)
    elseif mem === nothing
        return capacity_fpr(T, capacity, fpr)
    else
        return mem_fpr(T, mem, fpr)
    end
end

function FastCuckoo(; fpr=nothing, memory=nothing, capacity=nothing)
    return makefilter(FastCuckoo, fpr, memory, capacity)
end

function SmallCuckoo(; fpr=nothing, memory=nothing, capacity=nothing)
    return makefilter(SmallCuckoo, fpr, memory, capacity)
end

# Number of encoding bytes in a Bucket{F}. sizeof(Bucket) also includes noncoding bytes.
bucketsize(::Type{<:AbstractCuckooFilter{F}}) where {F} = F >> 1
bucketsize(x::AbstractCuckooFilter) = bucketsize(typeof(x))

"""
    sizeof(x::AbstractCuckooFilter)

Get the total RAM use of the cuckoo filter, including the underlying array.
"""
function Base.sizeof(x::AbstractCuckooFilter)
    return 48 + bucketsize(x) * x.nbuckets + sizeof(Bucket) - bucketsize(x)
end

capacityof(x::AbstractCuckooFilter) = 0.95 * 4 * x.nbuckets

# Probability of false positives given a completely full filter.
"""
    fprof(::Type{AbstractCuckooFilter{F}}) where {F}
    fprof(x::AbstractCuckooFilter)

Get the false positive rate for a fully filled AbstractCuckooFilter{F}.
The FPR is proportional to the fullness (a.k.a load factor).
"""
function fprof(::Type{AbstractCuckooFilter{F}}) where {F}
    prob_avoid_ejected = (2^F-2) / (2^F-1)
    prob_avoid_bucket = prod((2^F - 1 - i) / (2^F - i) for i in 1:4)
    return 1 - prob_avoid_ejected * prob_avoid_bucket * prob_avoid_bucket
end

fprof(x::AbstractCuckooFilter) = fprof(typeof(x))

function Base.show(io::IO, x::AbstractCuckooFilter{F}) where {F}
    print(io, lastindex(x), "-bucket ", typeof(x))
end

Base.summary(io::IO, x::AbstractCuckooFilter) = show(io, x)

function Base.show(io::IO, ::MIME"text/plain", x::AbstractCuckooFilter{F}) where {F}
    summary(io, x)
    println(io, ':')

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
Two equal arrays mean they behave identically. It does not mean they have been fed
the same data.
"""
Base.:(==)(x::AbstractCuckooFilter, y::AbstractCuckooFilter) = false
function Base.:(==)(x::AbstractCuckooFilter{F}, y::AbstractCuckooFilter{F}) where {F}
    return x.ejected == y.ejected && x.ejectedindex == y.ejectedindex && x.data == y.data
end

Base.hash(x::AbstractCuckooFilter) = hash(x.data, hash(x.ejected, hash(x.ejectedindex)))

"""
    isempty(x::AbstractCuckooFilter)

Test if the filter contains no elements.

# Examples
```
julia> a = FastCuckoo{12}(1<<12); isempty(a)
true
```
"""
Base.isempty(x::AbstractCuckooFilter) = all(i == 0x00 for i in x.data)


"""
    empty!(x::AbstractCuckooFilter)

Remove all elements from the filter.

# Examples
```
julia> a = FastCuckoo{12}(1<<12); push!(a, 1); isempty(a)
false
julia> empty!(a); isempty(a)
true
```
"""
function Base.empty!(x::AbstractCuckooFilter)
    x.ejected = typemin(UInt128)
    x.ejectedindex = typemin(UInt64)
    fill!(x.data, 0x00)
    return x
end


function Base.copy!(dst::AbstractCuckooFilter{F}, src::AbstractCuckooFilter{F}) where {F}
    lastindex(dst) != lastindex(src) && throw(ArgumentError("Must have same len."))
    unsafe_copyto!(dst.data, 1, src.data, 1, src.nbuckets)
    dst.ejected = src.ejected
    dst.ejectedindex = src.ejectedindex
    return dst
end
Base.copy(x::AbstractCuckooFilter) = copy!(typeof(x)(x.nbuckets), x)

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

function primaryindex(filter::AbstractCuckooFilter, val)
    return hash(val) & filter.mask + 1
end

function otherindex(filter::AbstractCuckooFilter, i::UInt64, fingerprint::UInt128)
    return ((i - 1) ⊻ hash(fingerprint)) & filter.mask + 1
end

function unsafe_getindex(x::FastCuckoo{F}, i) where {F}
    offset = (i-1)*bucketsize(x) + 1
    return unsafe_load(Ptr{Bucket{F}}(pointer(x.data, offset)), 1)
end

function unsafe_getindex(x::SmallCuckoo{F}, i) where {F}
    offset = (i-1)*bucketsize(x) + 1
    data = unsafe_load(Ptr{UInt128}(pointer(x.data, offset)), 1)
    return decode(data, Val{F}())
end

function unsafe_setindex!(x::FastCuckoo{F}, val::Bucket{F}, i) where {F}
    offset = (i-1)*bucketsize(x) + 1
    bitmask = mask(val)
    p = Ptr{UInt128}(pointer(x.data, offset))

    # Load old data so we don't overwrite old data when we write 16 bytes
    bits = unsafe_load(p, 1)

    # Now add in new data at the correct positions and write it back in
    bits &= ~bitmask
    bits |= (bitmask & val.data)
    unsafe_store!(p, bits, 1)
    return val
end

function unsafe_setindex!(x::SmallCuckoo{F}, val::Bucket{F}, i) where {F}
    offset = (i-1)*bucketsize(x) + 1
    bitmask = UInt128(1) << 4(F-1) - UInt128(1)
    p = Ptr{UInt128}(pointer(x.data, offset))

    # Load old data so we don't overwrite old data when we write 16 bytes
    bits = unsafe_load(p, 1)

    # Now add in new data at the correct positions and write it back in
    bits &= ~bitmask
    bits |= (bitmask & encode(val))
    unsafe_store!(p, bits, 1)
    return val
end

function Base.checkbounds(x::AbstractCuckooFilter, i)
    (i < 1 || i > lastindex(x)) && throw(BoundsError(x, i))
end

function Base.getindex(x::AbstractCuckooFilter, i)
    @boundscheck checkbounds(x, i)
    unsafe_getindex(x, i)
end

function Base.setindex!(x::AbstractCuckooFilter{F}, val::Bucket{F}, i) where {F}
    @boundscheck checkbounds(x, i)
    unsafe_setindex!(x, val, i)
end

# Fingerprint returns a UInt128 number in 1:2^F-1
function imprint(x, ::Val{F}) where {F}
    h = hash(x, FINGERPRINT_SALT)
    fingerprint = h & UInt(1 << F - 1)
    while fingerprint == typemin(UInt64) # Must not be zero
        h = h >> F + 1 # We add one to avoid infinite loop
        fingerprint = h & UInt(1 << F - 1)
    end
    return UInt128(fingerprint)
end

function Base.insert!(x::AbstractCuckooFilter, i, fingerprint::UInt128)
    bucket = unsafe_getindex(x, i)
    newbucket, success = insert!(bucket, fingerprint)
    unsafe_setindex!(x, newbucket, i)
    return success
end

function kick!(x::AbstractCuckooFilter, i, fingerprint::UInt128, bucketindex::Int)
    bucket = unsafe_getindex(x, i)
    newbucket, newfingerprint = kick!(bucket, fingerprint, bucketindex)
    unsafe_setindex!(x, newbucket, i)
    return newfingerprint
end

function pushfingerprint(filter::AbstractCuckooFilter, fingerprint, index)
    if filter.ejected != typemin(UInt128) # Filter is closed
        return fingerprint == filter.ejected
    end

    success = insert!(filter, index, fingerprint)
    if success
        return true
    end

    for kicks in 1:MAX_KICKS
        index = otherindex(filter, index, fingerprint)
        success = insert!(filter, index, fingerprint)
        if success
            return true
        end
        fingerprint = kick!(filter, index, fingerprint, rand(1:4))
    end

    filter.ejected = fingerprint
    filter.ejectedindex = index
    return true
end

function Base.push!(filter::AbstractCuckooFilter{F}, x) where {F}
    fingerprint = imprint(x, Val(F))
    index = primaryindex(filter, x)
    return pushfingerprint(filter, fingerprint, index)
end

function Base.in(x, filter::AbstractCuckooFilter{F}) where {F}
    fingerprint = imprint(x, Val(F))
    if fingerprint == filter.ejected
        return true
    end
    first_index = primaryindex(filter, x)
    bucket = unsafe_getindex(filter, first_index)
    if fingerprint in bucket
        return true
    else
        alternate_index = otherindex(filter, first_index, fingerprint)
        bucket = unsafe_getindex(filter, alternate_index)
        return fingerprint in bucket
    end
end

Base.haskey(filter::AbstractCuckooFilter, key) = key in filter

function Base.delete!(filter::AbstractCuckooFilter{F}, key) where {F}
    fingerprint = imprint(key, Val(F))
    index1 = primaryindex(filter, x)
    index2 = otherindex(filter, index1, fingerprint)
    unsafe_setindex!(filter, delete!(unsafe_getindex(filter, index1), fingerprint), index1)
    unsafe_setindex!(filter, delete!(unsafe_getindex(filter, index2), fingerprint), index2)

    # Having deleted an object, we can "open" a closed filter
    # by pushing the ejected value back into the buckets and zeroing the ejected
    if filter.ejected != typemin(UInt128)
        sucess = pushfingerprint(filter, filter.ejected, filter.ejectedindex)
        if sucess
            filter.ejected = typemin(UInt128)
            filter.ejectedindex = typemin(UInt128)
        end
    end
    return filter
end

function Base.union!(dst::AbstractCuckooFilter{F}, src::AbstractCuckooFilter{F}) where {F}
    dst.nbuckets != src.nbuckets && throw(ArgumentError("Must have same length."))
    for index in 1:lastindex(dst)
        dstbucket = unsafe_getindex(dst, index)
        srcbucket = unsafe_getindex(src, index)
        if isempty(dstbucket)
            unsafe_setindex!(dst, srcbucket, index)
        else
            for fingerprint in srcbucket
                success = pushfingerprint(dst, fingerprint, index)
                if !success
                    return false
                end
            end
        end
    end
    return true
end

function Base.union(x::AbstractCuckooFilter{F}, y::AbstractCuckooFilter{F}) where {F}
    x.nbuckets != y.nbuckets && throw(ArgumentError("Must have same length."))
    return union!(copy(x), y)
end
