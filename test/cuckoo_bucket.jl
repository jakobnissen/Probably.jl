function rand_fingerprint(F)
    if F > 16
        return rand(UInt128(1):UInt128(Probably.fingermask(Probably.Bucket128{F})))
    else
        return rand(UInt64(1):UInt64(Probably.fingermask(Probably.Bucket64{F})))
    end
end

function randbucket(F)
    b = String[]
    for i in 1:4
        if rand() < 0.2
            push!(b, string(typemin(UInt128), base=2, pad=F))
        else
            s = string(rand_fingerprint(F), base=2, pad=F)
            while s in b
                s = string(rand_fingerprint(F), base=2, pad=F)
            end
            push!(b, s)
        end
    end
    if F > 16
        return Probably.Bucket128{F}(parse(UInt128, join(b), base=2))
    else
        return Probably.Bucket64{F}(parse(UInt128, join(b), base=2))
    end
end

function inefficient_sort_bucket(x, F)
    T = ifelse(F > 16, Probably.Bucket128{F}, Probably.Bucket64{F})
    mask = Probably.fingermask(T) # already tested elsewhere
    a, b, c, d = x & mask, x >> F & mask, x >> 2F & mask, x >> 3F & mask
    a, b, c, d = Tuple(sort([a,b,c,d]))
    return T(d << 3F | c << 2F | b << F | a)
end

function inefficient_high_bits(x, F)
    T = ifelse(F > 16, UInt128, UInt64)
    r = String[]
    s = string(x, base=2, pad=128)
    for i in 1:4
        push!(r, s[end-i*F+1:end-i*F+4])
    end
    st = join(r)
    return parse(T, st, base=2)
end

function inefficient_low_bits(x, F)
    T = ifelse(F > 16, UInt128, UInt64)
    r = String[]
    s = string(x, base=2, pad=128)
    for i in 1:4
        push!(r, s[end-i*F+4+1:end-i*F+F])
    end
    st = join(r)
    if isempty(st)
        return typemin(T)
    else
        return parse(T, st, base=2)
    end
end

function test_putinbucket!(bucketdata, F)
    T = ifelse(F > 16, Probably.Bucket128{F}, Probably.Bucket64{F})
    T2 = ifelse(F > 16, UInt128, UInt64)
    b = T(T2(bucketdata))
    f = rand_fingerprint(F)
    while f in b
        f = rand_fingerprint(F)
    end
    newbucket, success = Probably.putinbucket!(b, f)
    findagain = f in newbucket
    return success, findagain
end

@testset "Misc Cuckoo Bucket" begin
mask_ok = true
for F in 1:32
    T = ifelse(F > 16, Probably.Bucket128{F}, Probably.Bucket64{F})
    T2 = ifelse(F > 16, UInt128, UInt64)
    x = rand(T2)
    mask_ok &= Probably.mask(T(x)) == parse(T2, "f"^F, base=16)
end
@test mask_ok

fingermask_ok = true
for F in 1:32
    T = ifelse(F > 16, Probably.Bucket128{F}, Probably.Bucket64{F})
    T2 = ifelse(F > 16, UInt128, UInt64)
    fingermask_ok &= Probably.fingermask(T) == parse(T2, "1"^F, base=2)
end
@test fingermask_ok
end # Misc Cuckoo Bucket

@testset "Imprint" begin
fingerprint_ok = true
for i in 1:100
    fingerprint_ok &= Probably.imprint(rand(Int), Probably.Bucket64{4}) != zero(UInt64)
end
@test fingerprint_ok
end # Imprint

@testset "Sort_bucket" begin
sort_bucket_ok = true
for i in 1:100
    F = rand(4:32)
    T = ifelse(F > 16, Probably.Bucket128{F}, Probably.Bucket64{F})
    T2 = ifelse(F > 16, UInt128, UInt64)
    x = rand(T2)
    sort_bucket_ok &= Probably.sort_bucket(T(x)) == inefficient_sort_bucket(x, F)
end
@test sort_bucket_ok
end # Sort_bucket

@testset "High & low bits" begin
highest_bits_ok = true
for i in 1:100
    F = rand(4:32)
    T = ifelse(F > 16, Probably.Bucket128{F}, Probably.Bucket64{F})
    T2 = ifelse(F > 16, UInt128, UInt64)
    x = rand(T2)
    given = Probably.highest_bits(T(x))
    trueval = inefficient_high_bits(x, F)
    highest_bits_ok &= given == trueval
end
@test highest_bits_ok

lowest_bits_ok = true
for i in 1:100
    F = rand(4:32)
    T = ifelse(F > 16, Probably.Bucket128{F}, Probably.Bucket64{F})
    T2 = ifelse(F > 16, UInt128, UInt64)
    x = rand(T2)
    given = Probably.lowest_bits(T(x))
    trueval = inefficient_low_bits(x, F)
    lowest_bits_ok &= given == trueval
end
@test lowest_bits_ok
end # High & low bits

@testset "Prefixes" begin
@test issorted(Probably.PREFIXES)
@test length(Probably.PREFIXES) == 3876
@test length(Set(Probably.PREFIXES)) == 3876
end

@testset "Encoding/decoding" begin
    encode_lessbits = true
    encode_sameresult = true

    for i in 1:100
        F = rand(4:32)
        T = ifelse(F > 16, Probably.Bucket128{F}, Probably.Bucket64{F})
        T2 = ifelse(F > 16, UInt128, UInt64)
        x = rand(T2)
        before = inefficient_sort_bucket(x, F)
        encoding = Probably.encode(T(x))
        decoding = Probably.decode(encoding, T)

        mask = ~(T2(1) << (4*(F-1)) - T2(1))

        encode_lessbits &= encoding & mask == T2(0)
        encode_sameresult &= before == decoding
    end

    @test encode_lessbits
    @test encode_sameresult
end # Encoding/decoding

@testset "Fingerprint membership" begin
    membership_ok = true
    for i in 1:100
        F = rand(4:32)
        T = ifelse(F > 16, Probably.Bucket128{F}, Probably.Bucket64{F})
        T2 = ifelse(F > 16, UInt128, UInt64)
        x = typemin(T2)
        f = rand_fingerprint(F)
        pos = rand(1:4)
        insert = rand() < 0.5
        if insert
            x |= f << (F*(pos-1))
        end

        membership_ok &= insert == (f in T(x))
    end
    @test membership_ok
end

@testset "Printing" begin
    buffer = IOBuffer()
    b = Probably.Bucket128{11}(0x8ac105b19ce81aede826a3d02a8a2e5b)
    print(buffer, b)
    @test String(take!(buffer)) == "| 65b  145  0aa  1e8 |"

    b = Probably.Bucket64{16}(0x00d51b0aff9001ef)
    print(buffer, b)
    @test String(take!(buffer)) == "| 01ef  ff90  1b0a  00d5 |"

    b = Probably.Bucket128{32}(0xc01c288aa84384128539300d6d03925e)
    print(buffer, b)
    @test String(take!(buffer)) == "| 6d03925e  8539300d  a8438412  c01c288a |"

    b = Probably.Bucket64{4}(0xf782551d70a228f8)
    print(buffer, b)
    @test String(take!(buffer)) == "| 8  f  8  2 |"
end

@testset "Put in bucket" begin
    putinbucket_ok = true

    # With F divisible by 4 (easier to check if it works)
    s, f = test_putinbucket!(0x111000222333, 12)
    putinbucket_ok &= (s == f && s)
    s, f = test_putinbucket!(0x111222333444, 12)
    putinbucket_ok &= (s == f && !s)
    s, f = test_putinbucket!(0x1230, 4)
    putinbucket_ok &= (s == f && s)
    s, f = test_putinbucket!(0x1234, 4)
    putinbucket_ok &= (s == f && !s)
    s, f = test_putinbucket!(0x44444444999999990000000011111111, 32)
    putinbucket_ok &= (s == f && s)
    s, f = test_putinbucket!(0x44444444999999995555555511111111, 32)
    putinbucket_ok &= (s == f && !s)

    @test putinbucket_ok
end # put in bucket

@testset "Kick bucket" begin
    kick_bucket_ok = true
    for i in 1:100
        F = rand(4:32)
        T = ifelse(F > 16, Probably.Bucket128{F}, Probably.Bucket64{F})
        T2 = ifelse(F > 16, UInt128, UInt64)
        x = rand(T2)
        pos = rand(1:4)
        b = T(x)
        mask = Probably.fingermask(T) << ((4-pos)*F)
        oldf = (x & mask) >> ((4-pos)*F)
        newf = rand_fingerprint(F)
        newbucket, oldf2 = Probably.kick!(b, newf, pos)
        kick_bucket_ok &= oldf2 == oldf && newf in newbucket
    end

    @test kick_bucket_ok
end # testset kick bucket

@testset "Pop from bucket" begin
    pop_bucket_ok = true
    for i in 1:100
        F = rand(4:32)
        T = ifelse(F > 16, Probably.Bucket128{F}, Probably.Bucket64{F})
        T2 = ifelse(F > 16, UInt128, UInt64)
        pos = rand(1:4)
        mask = Probably.fingermask(T) << ((4-pos)*F)
        b = randbucket(F)
        x = b.data
        f = (x & mask) >> ((4-pos)*F)
        while f == T2(0)
            b = randbucket(F)
            x = b.data
            f = (x & mask) >> ((4-pos)*F)
        end
        pop_bucket_ok &= f in b
        newbucket = pop!(b, f)
        pop_bucket_ok &= !(f in newbucket)
    end

    @test pop_bucket_ok
end
