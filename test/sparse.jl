A = sparse([2,4,3],[2,2,4],[0.2,0.4,0.6])
Af = full(A)

k = 0
for I in eachindex(stored(A))
    @test A[I] == A.nzval[k+=1]
end

k = 0
for j = inds(A, 2)
    for I in eachindex(stored(A, :, j))
        @test A[I] == A.nzval[k+=1]
    end
end

k = 0
for v in each(stored(A))
    @test v == A.nzval[k+=1]
end

k = 0
for j = inds(A, 2)
    for v in each(stored(A, :, j))
        @test v == A.nzval[k+=1]
    end
end

k = 0
for I in each(index(A))
    @test A[I] == Af[k+=1]
end

k = 0
for j = inds(A, 2)
    for I in each(index(A, :, j))
        @test A[I] == Af[k+=1]
    end
end

k = 0
for v in each(A)
    @test v == Af[k+=1]
end

k = 0
for j = inds(A, 2)
    for v in each(A, :, j)
        @test v == Af[k+=1]
    end
end

# Sparse matrix-vector multiplication
function matvecmul_ind!(b::AbstractVector, A::AbstractMatrix, x::AbstractVector)
    fill!(b, 0)
    inds(A, 2) == inds(x, 1) || throw(DimensionMismatch("inds(A, 2) = $(inds(A, 2)) does not agree with inds(x, 1) = $(inds(x, 1))"))
    for j in inds(A, 2)
        xj = x[j]
        for (ib, iA) in sync(Follower(index(b)), index(stored(A, :, j)))
            b[ib] += A[iA]*xj
        end
    end
    b
end
function matvecmul_val!(b::AbstractVector, A::AbstractMatrix, x::AbstractVector)
    fill!(b, 0)
    inds(A, 2) == inds(x, 1) || throw(DimensionMismatch("inds(A, 2) = $(inds(A, 2)) does not agree with inds(x, 1) = $(inds(x, 1))"))
    for j in inds(A, 2)
        xj = x[j]
        for (ib, a) in sync(Follower(index(b)), stored(A, :, j))
            b[ib] += a*xj
        end
    end
    b
end

x = [1,-5,7,-13]
btrue = A*x
b = similar(btrue)
matvecmul_ind!(b, A, x)
@test_approx_eq b btrue
matvecmul_val!(b, A, x)
@test_approx_eq b btrue
@test_throws DimensionMismatch matvecmul_ind!(b, A, [1])
@test_throws DimensionMismatch matvecmul_ind!([0.1,0.2], A, x)
@test_throws DimensionMismatch matvecmul_val!(b, A, [1])
@test_throws DimensionMismatch matvecmul_val!([0.1,0.2], A, x)
