module TestHyperLogLog

using Test
using HyperLogLog

const P_LOW = 4
const P_HIGH = 18

function getdifferent()
    a, b = rand(P_LOW:P_HIGH), rand(P_LOW:P_HIGH)
    while a == b
        a = rand(P_LOW:P_HIGH)
    end
    return HLL{a}(), HLL{b}()
end

function test_isidentical(x::HLL{P1}, y::HLL{P2}) where {P1, P2}
    @test P1 == P2
    @test x == y
    @test x.counts == y.counts
    @test length(x) == length(y)
    @test union(x, y) == x == y
end

randomhll() = HLL{rand(P_LOW:P_HIGH)}()

# Instantiation
@testset "Instantiation" begin
for i in P_LOW:P_HIGH
    x = HLL{i}()
    @test length(x.counts) == 2^i
end

a = HLL{14}()
b = HLL()
@test a == b

@test_throws ArgumentError a = HLL{3}()
@test_throws ArgumentError a = HLL{19}()
@test_throws ArgumentError a = HLL{Int}()
end # instantiation

@testset "Sizeof" begin
for i in P_LOW:P_HIGH
    x = HLL{i}()
    @test sizeof(x.counts) == sizeof(x)
end
end # Sizeof

@testset "Equality" begin
for i in 1:100
    a, b = getdifferent()
    @test a != b

    p = rand(P_LOW:P_HIGH)
    x, y = HLL{p}(), HLL{p}()

    @test x == y
    r = rand()
    push!(x, r)
    @test x != y
    push!(y, r)
    @test x == y

    r = rand(Int, 100)
    for i in r
        push!(x, i)
    end
    @test x != y
    for i in r
        push!(y, i)
    end
    @test x == y
end
end # Equality

@testset "Union" begin
for i in 1:100
    p = rand(P_LOW:P_HIGH)
    x, y, combined = HLL{p}(), HLL{p}(), HLL{p}()

    for i in 1:5000
        r, element = rand(), rand(Int)
        r < 0.66 && push!(x, element)
        r > 0.33 && push!(y, element)
        push!(combined, element)
    end

    test_isidentical(union(x, y), combined)
    union!(x, y)
    test_isidentical(x, combined)
end
end # Union

@testset "Copying" begin
for i in 1:100
    x = randomhll()

    for i in 1:100
        push!(x, rand(1:100))
    end

    y = copy(x)
    test_isidentical(x, y)

    for i in 1:100
        push!(x, rand(1:100))
    end

    copy!(y, x)
    test_isidentical(x, y)
end
end # Copying

@testset "Empty" begin
for i in 1:100
    x = randomhll()
    @test isempty(x)
    push!(x, rand())
    @test !isempty(x)
    empty!(x)
    @test isempty(x)
    @test length(x) < 5 # tolerable error

    # Add some more elements
    for i in 1:100
        push!(x, rand())
    end
    @test !isempty(x)
    empty!(x)
    @test isempty(x)
end
end # Empty

end # module
