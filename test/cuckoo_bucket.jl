rand_fingerprint(F) = rand(UInt128(1):UInt128(Probably.fingermask(Probably.Bucket{F})))

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
    return Probably.Bucket{F}(parse(UInt128, join(b), base=2))
end


function inefficient_sort_bucket(x::UInt128, F)
    mask = Probably.fingermask(Probably.Bucket{F}) # already tested elsewhere
    a, b, c, d = x & mask, x >> F & mask, x >> 2F & mask, x >> 3F & mask
    a, b, c, d = Tuple(sort([a,b,c,d]))
    return Probably.Bucket{F}(d << 3F | c << 2F | b << F | a)
end

function inefficient_high_bits(x::UInt128, F)
    r = String[]
    s = string(x, base=2, pad=128)
    for i in 1:4
        push!(r, s[end-i*F+1:end-i*F+4])
    end
    st = join(r)
    return parse(UInt128, st, base=2)
end

function inefficient_low_bits(x::UInt128, F)
    r = String[]
    s = string(x, base=2, pad=128)
    for i in 1:4
        push!(r, s[end-i*F+4+1:end-i*F+F])
    end
    st = join(r)
    if isempty(st)
        return typemin(UInt128)
    else
        return parse(UInt128, st, base=2)
    end
end

function test_putinbucket!(bucketdata, F)
    b = Probably.Bucket{F}(UInt128(bucketdata))
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
    x = rand(UInt128)
    mask_ok &= Probably.mask(Probably.Bucket{F}(x)) == parse(UInt128, "f"^F, base=16)
end
@test mask_ok

fingermask_ok = true
for F in 1:32
    fingermask_ok &= Probably.fingermask(Probably.Bucket{F}) == parse(UInt128, "1"^F, base=2)
end
@test fingermask_ok
end # Misc Cuckoo Bucket

@testset "Imprint" begin
fingerprint_ok = true
for i in 1:10000
    fingerprint_ok &= Probably.imprint(rand(Int), Probably.Bucket{4}) != zero(UInt128)
end
@test fingerprint_ok
end # Imprint

@testset "Sort_bucket" begin
sort_bucket_ok = true
for i in 1:10000
    x = rand(UInt128)
    F = rand(4:32)
    sort_bucket_ok &= Probably.sort_bucket(Probably.Bucket{F}(x)) == inefficient_sort_bucket(x, F)
end
@test sort_bucket_ok
end # Sort_bucket

@testset "High & low bits" begin
highest_bits_ok = true
for i in 1:100
    x = rand(UInt128)
    F = rand(4:32)
    given = Probably.highest_bits(Probably.Bucket{F}(x))
    trueval = inefficient_high_bits(x, F)
    highest_bits_ok &= given == trueval
end
@test highest_bits_ok

lowest_bits_ok = true
for i in 1:100
    x = rand(UInt128)
    F = rand(4:32)
    given = Probably.lowest_bits(Probably.Bucket{F}(x))
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

    for i in 1:1000
        x = rand(UInt128)
        F = rand(4:32)
        before = inefficient_sort_bucket(x, F)
        encoding = Probably.encode(Probably.Bucket{F}(x))
        decoding = Probably.decode(encoding, Val(F))

        mask = ~(UInt128(1) << (4*(F-1)) - UInt128(1))

        encode_lessbits &= encoding & mask == UInt128(0)
        encode_sameresult &= before == decoding
    end

    @test encode_lessbits
    @test encode_sameresult
end # Encoding/decoding

@testset "Fingerprint membership" begin
    membership_ok = true
    for i in 1:1000
        x = typemin(UInt128)
        F = rand(4:32)
        f = rand_fingerprint(F)
        pos = rand(1:4)
        insert = rand() < 0.5
        if insert
            x |= f << (F*(pos-1))
        end

        membership_ok &= insert == (f in Probably.Bucket{F}(x))
    end
    @test membership_ok
end

@testset "Printing" begin
    buffer = IOBuffer()
    b = Probably.Bucket{11}(0x8ac105b19ce81aede826a3d02a8a2e5b)
    print(buffer, b)
    @test String(take!(buffer)) == "| 65b  145  0aa  1e8 |"

    b = Probably.Bucket{16}(0x000000000000000000d51b0aff9001ef)
    print(buffer, b)
    @test String(take!(buffer)) == "| 01ef  ff90  1b0a  00d5 |"

    b = Probably.Bucket{32}(0xc01c288aa84384128539300d6d03925e)
    print(buffer, b)
    @test String(take!(buffer)) == "| 6d03925e  8539300d  a8438412  c01c288a |"

    b = Probably.Bucket{4}(0x7669c12ee7e43e74f782551d70a228f8)
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
    for i in 1:1000
        x = rand(UInt128)
        pos = rand(1:4)
        F = rand(4:32)
        b = Probably.Bucket{F}(x)
        mask = Probably.fingermask(Probably.Bucket{F}) << ((4-pos)*F)
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
        pos = rand(1:4)
        mask = Probably.fingermask(Probably.Bucket{F}) << ((4-pos)*F)
        b = randbucket(F)
        x = b.data
        f = (x & mask) >> ((4-pos)*F)
        while f == UInt128(0)
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
