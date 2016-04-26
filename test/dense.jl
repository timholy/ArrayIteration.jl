A = [1 5 -5;
     0 3 2]
B = sub(A, 1:2, 1:3)

@test each(index(A)) == eachindex(A) == 1:length(A)
@test each(index(B)) == CartesianRange((1:2, 1:3))
@test each(index(A, :, 1:2)) == 1:4
@test each(index(B, :, 1:2)) == CartesianRange((1:2, 1:2))
@test each(index(A, :, 2:3)) == 3:6
@test each(index(B, :, 2:3)) == CartesianRange((1:2, 2:3))
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
R = reshape(sub(Array{Int}(3,2,3), 1:2, 1:1, 1:2), (2, 2))

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
fill!(R, -1)
@test goodcopy!(R, A) == A

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
fill!(R, -1)
@test goodcopy!(R, A) == A

iter = sync(index(A), index(R))
(IA, IR) = first(iter)
@test isa(IR, Base.ReshapedIndex)

# TODO: uncomment when sync+stored is implemented
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

# 1-argument case
function mysum1a(A)
    s = 0.0
    for (a,) in sync(A)
        s += a
    end
    s
end

function mysum1b(A)
    s = 0.0
    for (I,) in sync(index(A))
        s += A[I]
    end
    s
end

@test_approx_eq mysum1a(A) sum(A)
@test_approx_eq mysum1b(A) sum(A)

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

# sync with dimension iterators
fill!(B, -1)
for (I, a) in sync(index(B, :, 2), value(A, :, 1))
    B[I] = a
end
@test B == [-1 A[1,1]; -1 A[2,1]]
fill!(B, -1)
for (IB, IA) in sync(index(B, :, 1), index(A, :, 2))
    B[IB] = A[IA]
end
@test B == [A[1,2] -1; A[2,2] -1]

## optimized ReshapedArray iterators
A = reshape(1:12, 4, 3)    # LinearFast
@test each(index(A, :, 2)) == 5:8
@test each(index(A, 2:3, 3)) == 10:11
A = sub(copy(reshape(1:15, 5, 3)), 1:4, :)  # LinearSlow
a = reshape(A, 12)
@test each(index(a, 1:4)) == CCI(CartesianRange(size(A)),
                                 CartesianRange(CartesianIndex(1,1),CartesianIndex(4,1)))
k = 0
for I in each(index(a, 1:4))
    @test a[I] == a[k+=1]
end
@test each(index(a, 3:9)) == CCI(CartesianRange(size(A)),
                                 CartesianRange(CartesianIndex(3,1),CartesianIndex(1,3)))
k = 2
for I in each(index(a, 3:9))
    @test a[I] == a[k+=1]
end

function sum_cols_slow!(S, A)  # slow for ReshapedArrays
    fill!(S, 0)
    @assert inds(S,2) == inds(A,2)
    for j in inds(A,2)
	tmp = S[1,j]
	@inbounds for i in inds(A, 1)
	    tmp += A[i,j]
	end
	S[1,j] = tmp
    end
    S
end

function sum_cols_fast!(S, A)
    fill!(S, 0)
    @assert inds(S,2) == inds(A,2)
    for j in inds(A,2)
	tmp = S[1,j]
	@inbounds for I in each(index(A, :, j))
	    tmp += A[I]
	end
	S[1,j] = tmp
    end
    S
end

A = rand(1000,1,999)
B = sub(A, 1:size(A,1)-1, 1, 1:size(A,3)-1)
R = reshape(B, (size(B,1),size(B,3)))
@test isa(each(index(R, :, 2)), CCI)
S1 = zeros(1,size(R,2))
S2 = similar(S1)
@test sum_cols_fast!(S1, R) == sum_cols_slow!(S2, R)
