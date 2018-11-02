module t

using Test
using Probably

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
    @test x.ejected === UInt128(0)
    @test x.ejectedindex === UInt64(0)
    @test x.mask == UInt64((1 << 8) - 1)
    @test length(x.data) == (1<<8)*6 + 10
end

end

@testset "Misc" begin
x = FastCuckoo{12}(1<<4)
y = SmallCuckoo{12}(1<<4)
@test eltype(x) == Probably.Bucket{12}
@test eltype(y) == Probably.Bucket{13}
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

@testset "Indexing" begin
    for T in (FastCuckoo{12}, SmallCuckoo{11})
        x = T(1 << 10)
        @test x[1] == Probably.Bucket{12}(0)
        @test x[end] == Probably.Bucket{12}(0)
        @test x[x.nbuckets] == Probably.Bucket{12}(0)
        @test x[lastindex(x)] == Probably.Bucket{12}(0)

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
    end
end

@testset "Setting and getting" begin
end

end # module
