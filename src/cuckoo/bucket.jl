# This simply creates a "new" hash function to create fingerprints.
const FINGERPRINT_SALT = 0x7afb47f99881a598

struct Bucket{F}
    data::UInt128
end

# Bitwise AND with the fingermask to removes noncoding bits from a Bucket
mask(x::Bucket{F}) where {F} = UInt128(1) << 4F - UInt128(1)

# Bitwise AND with the fingermask zeros removes bits from an UInt128 that are
# noncoding in a fingerprint. Fingerprints themselves always have those bits zeroed.
fingermask(::Type{Bucket{F}}) where {F} = UInt128(1) << F - UInt128(1)
fingermask(x::Bucket{F}) where {F} = fingermask(typeof(x))

# Fingerprint returns a UInt128 number in 1:2^F-1
function imprint(x, ::Type{Bucket{F}}) where {F}
    h = hash(x, FINGERPRINT_SALT)
    fingerprint = h & UInt(1 << F - 1)
    while fingerprint == typemin(UInt64) # Must not be zero
        h = h >> F + 1 # We add one to avoid infinite loop
        fingerprint = h & UInt(1 << F - 1)
    end
    return UInt128(fingerprint)
end

function Base.:(==)(x::Bucket{F}, y::Bucket{F}) where {F}
    x.data & fingermask(x) == y.data & fingermask(y)
end

Base.:(==)(x::Bucket, y::Bucket) = false

# Sorted array of all UInt16 where each block of 4 bits are themselves sorted
let x = Set{UInt16}()
    for a in 0:15, b in 0:15, c in 0:15, d in 0:15
        k,m,n,p = sort!([a, b, c, d])
        y = UInt16(k) << 12 | UInt16(m) << 8 | UInt16(n) << 4 | UInt16(p)
        push!(x, y)
    end
    global const PREFIXES = collect(x)
    sort!(PREFIXES)
end

# Sorts the four fingerprint in the bucket
@inline function sort_bucket(x::Bucket{F}) where {F}
    a, b = minmax(x.data & fingermask(x), x.data >> F & fingermask(x))
    c, d = minmax(x.data >> 2F & fingermask(x), x.data >> 3F & fingermask(x))
    a, c = minmax(a, c)
    b, d = minmax(b, d)
    b, c = minmax(b, c)
    return Bucket{F}(d << 3F | c << 2F | b << F | a)
end

# Get 4 highest bits of each fingerprint
@inline function highest_bits(x::Bucket{F}) where {F}
    y = typemin(UInt128)
    bitmask = UInt128(15)
    y = (y << 4) | (x.data >> (F-4) & bitmask)
    y = (y << 4) | (x.data >> (2F-4) & bitmask)
    y = (y << 4) | (x.data >> (3F-4) & bitmask)
    y = (y << 4) | (x.data >> (4F-4) & bitmask)
end

# Get the F-4 lowest bits of each fingerprint
@inline function lowest_bits(x::Bucket{F}) where {F}
    y = typemin(UInt128)
    bitmask = fingermask(x) >> 4
    y = (y << (F-4)) | (x.data & bitmask)
    y = (y << (F-4)) | (x.data >> F & bitmask)
    y = (y << (F-4)) | (x.data >> 2F & bitmask)
    y = (y << (F-4)) | (x.data >> 3F & bitmask)
    return y
end

# Encode to UInt128 with bits in this order: NONCODINGBITS-CODINGBITS-INDEX
# Index is I-1 where I is the index in PREFIXES which encodes the "highbits"
# of the decoded value
@inline function encode(bucket::Bucket{F}) where {F}
    sorted_bucket = sort_bucket(bucket)
    high_bits = highest_bits(sorted_bucket)

    # The encoded bits must be able to be zero, so here they are subtracted 1
    index = reinterpret(UInt64, searchsortedfirst(PREFIXES, high_bits) - 1)
    result = lowest_bits(sorted_bucket)
    result = result << 12 | UInt128(index)
    return result
end

# Exactly inverse of encode.
@inline function decode(x::UInt128, ::Val{F}) where {F}
    lowbitmask = fingermask(Bucket{F}) >> 4
    highbitmask = UInt128(15)
    @inbounds high_bits = PREFIXES[x & UInt64(4095) + 1]
    low_bits = x >> 12
    result = typemin(UInt128)
    for i in 1:4
        result = result << 4 | (high_bits & highbitmask)
        result = result << (F-4) | (low_bits & lowbitmask)
        high_bits >>>= 4
        low_bits >>>= (F-4)
    end
    return Bucket{F}(result)
end

function showfingerprint(fingerprint::UInt128, ::Val{F}) where {F}
    if fingerprint == typemin(fingerprint)
        return " "^cld(F, 4)
    else
        return string(fingerprint, base=16, pad=cld(F, 4))
    end
end

function Base.show(io::IO, x::Bucket{F}) where {F}
    a = showfingerprint(fingermask(x) & x.data, Val(F))
    b = showfingerprint(fingermask(x) & x.data >> F, Val(F))
    c = showfingerprint(fingermask(x) & x.data >> 2F, Val(F))
    d = showfingerprint(fingermask(x) & x.data >> 3F, Val(F))
    print(io, '|', ' ', a, "  ", b, "  ", c, "  ", d, ' ', '|')
end

# A fingerprint is in a bucket if any of the 4 fingerprints in a bucket is equal
function Base.in(fingerprint::UInt128, bucket::Bucket{F}) where {F}
    isin = false
    isin |= bucket.data & fingermask(bucket) == fingerprint
    isin |= bucket.data >> F & fingermask(bucket) == fingerprint
    isin |= bucket.data >> 2F & fingermask(bucket) == fingerprint
    isin |= bucket.data >> 3F & fingermask(bucket) == fingerprint
    return isin
end

Base.isempty(x::Bucket) = x.data & mask(x) == typemin(UInt128)

# Produces only nonzero fingerprints
function Base.iterate(bucket::Bucket{F}, state=(bucket.data, 1)) where {F}
    data, i = state
    if i == 5
        return nothing
    else
        fingerprint = data & fingermask(bucket)
        if fingerprint == typemin(UInt128)
            return iterate(bucket, (data >> F, i+1))
        else
            return fingerprint, (data >> F, i+1)
        end
    end
end

# Inserts a fingerprint into the leftmost empty slot. If the fingerprint is
# seen, change nothing. Return the changed bucket and whether or not it was
# successful (ie. inserted or already in the bucket)
function putinbucket!(bucket::Bucket{F}, fingerprint::UInt128) where {F}
    y = bucket.data
    success = false
    if y >> 3F & fingermask(bucket) == typemin(UInt128) || y >> 3F & fingermask(bucket) == fingerprint
        y = y | fingerprint << 3F
        success = true
    elseif y >> 2F & fingermask(bucket) == typemin(UInt128) || y >> 2F & fingermask(bucket) == fingerprint
        y = y | fingerprint << 2F
        success = true
    elseif y >> F & fingermask(bucket) == typemin(UInt128) || y >> F & fingermask(bucket) == fingerprint
        y = y | fingerprint << F
        success = true
    elseif y & fingermask(bucket) == typemin(UInt128) || y & fingermask(bucket) == fingerprint
        y = y | fingerprint
        success = true
    end
    return Bucket{F}(y), success
end

# Insert value into bucket, kicking out existing value.
# Returns bucket, kicked_out_fingerprint
function kick!(bucket::Bucket{F}, fingerprint::UInt128, bucketindex::Int) where {F}
    y = bucket.data
    shift = 4F - bucketindex*F
    mask = fingermask(bucket) << shift
    existing = (y & mask) >> shift
    y &= ~mask # Zero out bits of existing fingerprint
    y |= fingerprint << shift # Now add in the new fingerprint
    return Bucket{F}(y), existing
end

# Creates a new bucket with the fingerprint deleted from it, if it was in it
function Base.pop!(bucket::Bucket{F}, fingerprint::UInt128) where {F}
    y = bucket.data
    if y >> 3F & fingermask(bucket) == fingerprint
        return Bucket{F}(y & ~(fingermask(bucket) << 3F))
    elseif y >> 2F & fingermask(bucket) == fingerprint
        return Bucket{F}(y & ~(fingermask(bucket) << 2F))
    elseif y >> F & fingermask(bucket) == fingerprint
        return Bucket{F}(y & ~(fingermask(bucket) << F))
    elseif y & fingermask(bucket) == fingerprint
        return Bucket{F}(y & ~fingermask(bucket))
    else
        return bucket
    end
end

function ff(a)
    isin = 0
    for i in 1<<14:1<<25
        isin += ifelse(i in a, 1, 0)
    end
    return isin
end
