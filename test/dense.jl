A = [1 5 -5;
     0 3 2]
B = sub(A, 1:2, 1:3)

@test each(index(A)) == eachindex(A) == 1:length(A)
@test each(index(B)) == CartesianRange((1:2, 1:3))
@test each(index(A, :, 1:2)) == CartesianRange((1:2, 1:2))
@test each(index(A, :, 2:3)) == CartesianRange((1:2, 2:3))
@test each(index(A, 1, :)) == CartesianRange((1, 1:3))

k = 0
for v in each(A)
    @test v == A[k+=1]
end

k = 0
for I in each(index(A))
    @test A[I] == A[k+=1]
end

k = 0
for I in eachindex(A)
    @test A[I] == A[k+=1]
end

k = 0
for j in inds(A, 2)
    for v in each(A, :, j)
        @test v == A[k+=1]
    end
end

k = 0
for j in inds(A, 2)
    for I in each(index(A, :, j))
        @test A[I] == A[k+=1]
    end
end

k = 0
for j in inds(A, 2)
    for I in eachindex(stored(A, :, j))
        @test A[I] == A[k+=1]
    end
end

k = 0
for j in inds(A, 2)
    for v in each(stored(A, :, j))
        @test v == A[k+=1]
    end
end

A = Int[1 3; 2 4]
B = Array{Int}(2, 2)
C = PermutedDimsArray(Array{Int}(2, 2), [2,1])

function badcopy!(dest, src)
    for (I, s) in zip(eachindex(dest), src)
        dest[I] = s
    end
    dest
end

fill!(B, -1)
@test badcopy!(B, A) == A
fill!(C, -1)
badcopy!(C, A)
@test C[2,1] != A[2,1]   # oops!
@test C[2,1] == A[1,2]

function goodcopy!(dest, src)
    for (I, s) in sync(index(dest), src)
        dest[I] = s
    end
    dest
end

fill!(B, -1)
@test goodcopy!(B, A) == A
fill!(C, -1)
goodcopy!(C, A)
@test C[2,1] == A[2,1]
@test C[1,2] == A[1,2]

D = ATs.OA(Array{Int}(2,2), (-1,2))
@test_throws DimensionMismatch goodcopy!(D, A)
E = ATs.OA(A, (-1,2))
goodcopy!(D, E)
@test D[0,3] == 1
@test D[1,3] == 2
@test D[0,4] == 3
@test D[1,4] == 4
D = ATs.OA(Array{Int}(2,2), (-2,2))
@test_throws DimensionMismatch goodcopy!(D, E)
D = ATs.OA(Array{Int}(2,2), (-1,1))
@test_throws DimensionMismatch goodcopy!(D, E)

function goodcopy2!(dest, src)
    for (Idest, Isrc) in sync(index(dest), index(src))
        dest[Idest] = src[Isrc]
    end
    dest
end

fill!(B, -1)
@test goodcopy2!(B, A) == A
fill!(C, -1)
goodcopy2!(C, A)
@test C[2,1] == A[2,1]
@test C[1,2] == A[1,2]

# function goodcopy3!(dest, src)
#     for (I, s) in sync(index(dest), stored(src))
#         dest[I] = s
#     end
#     dest
# end

# fill!(B, -1)
# @test goodcopy3!(B, A) == A
# fill!(C, -1)
# goodcopy3!(C, A)
# @test C[2,1] == A[2,1]
# @test C[1,2] == A[1,2]

# 3-argument form
function mysum!(dest, A, B)
    for (Idest, a, b) in sync(index(dest), A, B)
        dest[Idest] = a + b
    end
    dest
end

C = PermutedDimsArray([10 30; 20 40], [2,1])
D = fill(-1, (2,2))
@test mysum!(D, A, C) == Int[11 23; 32 44]
D = fill(-1, (2,2))
@test mysum!(D, C, A) == Int[11 23; 32 44]
Cc = goodcopy!(similar(A), C)
@test isa(Cc, Array)
D = fill(-1, (2,2))
@test mysum!(D, Cc, A) == Int[11 23; 32 44]
goodcopy!(D, Cc)
mysum!(C, D, A)
@test C[1,2] == 23
@test C[2,1] == 32
