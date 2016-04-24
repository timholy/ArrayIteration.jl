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

A = copy(reshape(1:4, 2, 2))
B = Array{Int}(2, 2)
C = PermutedDimsArray(Array{Int}(2, 2), [2,1])

function badcopy!(dest, src)
    for (I, s) in zip(eachindex(dest), src)
        dest[I] = s
    end
    dest
end

@test badcopy!(B, A) == A
badcopy!(C, A)
@test C[2,1] != A[2,1]   # oops!
@test C[2,1] == A[1,2]

function goodcopy!(dest, src)
    for (I, s) in sync(index(dest), src)
        dest[I] = s
    end
    dest
end

@test goodcopy!(B, A) == A
@test B[2,1] == A[2,1]
@test B[1,2] == A[1,2]

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
