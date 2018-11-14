@testset "Manual instantiation" begin
@test_throws ArgumentError x = FastCuckoo{2}(1<<4)
@test_throws ArgumentError x = FastCuckoo{33}(1<<4)
@test_throws ArgumentError x = FastCuckoo{-2}(1<<4)
@test_throws ArgumentError x = FastCuckoo{12}(1<<4 + 1)
@test_throws ArgumentError x = FastCuckoo{12}(2)

@test_throws ArgumentError x = SmallCuckoo{1}(1<<4)
@test_throws ArgumentError x = SmallCuckoo{32}(1<<4)
@test_throws ArgumentError x = SmallCuckoo{-2}(1<<4)
@test_throws ArgumentError x = SmallCuckoo{12}(1<<4 + 1)
@test_throws ArgumentError x = SmallCuckoo{12}(2)

for T in (FastCuckoo{12}, SmallCuckoo{12})
    x = T(1<<10)
    @test x.nbuckets === 1<<8
    @test x.ejected === UInt64(0)
    @test x.ejectedindex === UInt64(0)
    @test x.mask == UInt64((1 << 8) - 1)
end

end

@testset "Misc" begin
x = FastCuckoo{12}(1<<4)
y = SmallCuckoo{12}(1<<4)
@test eltype(x) == Probably.Bucket64{12}
@test eltype(y) == Probably.Bucket64{13}
end

@testset "Equality and hasing" begin
for T in (FastCuckoo{12}, SmallCuckoo{12})
    x = T(1<<10)
    y = T(1<<10)

    @test x == y
    @test hash(x) == hash(y)

    rands = rand(100)
    for i in rands
        push!(x, i)
    end

    @test x != y
    @test hash(x) != hash(y)

    for i in rands
        push!(y, i)
    end

    @test x == y
    @test hash(x) == hash(y)
end
end

@testset "Emptying" begin
for T in (FastCuckoo{12}, SmallCuckoo{12})
    x = T(1<<10)

    @test isempty(x)
    for i in 1:100
        push!(x, rand())
    end
    @test !isempty(x)
    empty!(x)
    @test isempty(x)
end
end

@testset "Copying" begin
for T in (FastCuckoo, SmallCuckoo)
    x = T{12}(1<<10)
    y = T{12}(1<<10)
    for i in 1:100
        push!(x, rand())
    end
    @test copy(x) == x
    @test copy(y) == y

    copy!(x, y)
    @test x == y

    p, q = T{12}(1<<4), T{11}(1<<4)
    @test_throws MethodError copy!(p, q)
    @test_throws MethodError copy!(x, q)
    @test_throws ArgumentError copy!(x, p)
end
end

@testset "Loadfactor" begin
for T in (FastCuckoo{31}, SmallCuckoo{31})
    x = T(1 << 10)
    for i in 1:1<<8
        push!(x, rand())
    end
    @test 0.24 < loadfactor(x) < 0.26 # some collisions may happen
end
end

@testset "Indexing and assigning" begin
for T in (FastCuckoo{12}, SmallCuckoo{11})
    x = T(1 << 10)
    @test x[1] == Probably.Bucket64{12}(0)
    @test x[end] == Probably.Bucket64{12}(0)
    @test x[x.nbuckets] == Probably.Bucket64{12}(0)
    @test x[lastindex(x)] == Probably.Bucket64{12}(0)

    alternate_index_ok = true
    for i in 1:100
        r = rand()
        f = Probably.imprint(r, eltype(x))
        p1 = Probably.primaryindex(x, r)
        p2 = Probably.otherindex(x, p1, f)
        p3 = Probably.otherindex(x, p2, f)
        alternate_index_ok &= p3 == p1
    end
    @test alternate_index_ok

    setting_index_ok = true
    for i in 1:100
        pos = rand(1:1 << 8)
        r = rand(UInt64)
        b = inefficient_sort_bucket(r, 12)
        x[pos] = b
        b2 = x[pos]
        setting_index_ok &= b == b2
    end
    @test setting_index_ok
end
end

@testset "Pop!" begin
for T in (FastCuckoo{12}, SmallCuckoo{11})
    x = T(1 << 10)
    values = Set(rand(Int8, 100)) # No duplicates!
    for v in values
        push!(x, v)
    end
    pop_ok = true
    for v in values
        pop_ok &= v in x
        pop!(x, v)
        pop_ok &= !(v in x)
    end
    @test pop_ok
end
end

@testset "Union" begin
for T in (FastCuckoo{12}, SmallCuckoo{11})
    x, y = T(1 << 10), T(1 << 10)
    for i in 1:100
        push!(x, rand())
    end
    @test x != y
    z, success = union(x, y)
    @test z == x
    union!(y, x)
    @test x == y
    for i in 1:100
        push!(x, rand())
        push!(y, rand())
    end
    union!(z, x)
    @test z != y
end
end
