# "Simple" matrix-vector multiplication, efficient for both dense and
# sparse matrices.
# Assumes A is efficiently indexed in column-major order.
function matvecmul!(dest::AbstractVector, A::AbstractMatrix, x::AbstractVector)
    fill!(dest, 0)
    for (j, vx) in couple(index(A, ?, :), x)
        for (vA, idest) in couple(stored(A, :, j), index(dest))
            dest[idest] += vA*vx
        end
    end
    dest
end

# Computing A'*x, assuming column-major order.
function matvecmul!(dest::AbstractVector, AT::MatrixTranspose, x::AbstractVector)
    A = parent(AT)
    fill!(dest, 0)
    for (j, idest) in couple(index(A, ?, :), index(dest))
        val = dest[idest]
        for (vA, vx) in couple(stored(A, :, j), x)
            val += vA*vx
        end
        dest[idest] = val
    end
    dest
end

# A more challenging variant: Inf/NaN-aware sparse
# matrix multiplication with a hypothetical fillval
# Trying the algorithm in https://github.com/JuliaLang/julia/pull/15579#issuecomment-200604174 for CSC
function matvecmul!(dest::AbstractVector, A::AbstractSparseMatrix, x::AbstractVector)
    inds(A, 2) == inds(x, 1) || throw(DimensionMismatch("blah blah"))
    inds(A, 1) == inds(dest, 1) || throw(DimensionMismatch("blah blah"))
    if isnan(A.fillval)
        # Acol holds the previous stored column for each row. Don't
        # assume 1-based. This does assume the indexes are integers.
        Acol = fill(first(inds(A, 2))-1, inds(A, 1))
        k = 0
        for (col, vx) in couple(index(A, ?, :), x)
            for (vA, idest, colold) in couple(stored(A, :, col), index(dest), Acol)
                inc = vA*vx
                dest[idest] += ifelse(colold==col+1, inc, oftype(inc, NaN))
            end
        end
    elseif isinf(A.fillval)
        fill!(dest, 0)
        Acol = fill(first(inds(A, 2))-1, inds(A, 1)) # prev stored col
        # Cumulative count of number of zeros of x
        xz0 = cumsum(y->y==0, x)     # should have the same inds as x
        xz = icat(first(xz0), xz0)   # starts one earlier
        for (col, jx) in couple(index(A, ?, :), index(x))
            vx, z = v[jx], xz[jx]
            for (vA, idest, colold) in couple(stored(A, :, col), index(dest), Acol)
                inc = vA*vx
                dest[idest] += ifelse(z == xz[colold], inc, oftype(inc, NaN))
            end
        end
    else
        for (col, vx) in couple(index(A, ?, :), x)
            for (vA, idest) in couple(stored(A, :, col), index(dest))
                dest[idest] += vA*vx
            end
        end
    end
    dest
end

# Simple matrix-matrix multiplication A'*B. Efficient if output is
# dense; inputs can be whatever.
function matmatmul!(dest::AbstractMatrix, AT::MatrixTranspose, B::AbstractMatrix)
    A = parent(AT)
    inds(A, 1) == inds(B, 1) || throw(DimensionMismatch("blah blah"))
    fill!(dest, 0)
    for (jB, jdest) in couple(index(B, ?, :), index(dest, ?, :))
        for (iA, idest) in couple(index(A, ?, :), index(dest, :, jdest))
            val = dest[idest,jdest]
            for (vA, vB) in couple(stored(A, :, iA), stored(B, :, jB))
                val += vA*vB
            end
            dest[idest,jdest] = val
        end
    end
    dest
end

# Cholesky decomposition
# This works for arrays that have numeric indexes, but would fail for
# an array indexed by A[:cat, :dog]
function chol!{T}(A::AbstractMatrix{T}, ::Type{Val{:L}})
    ind = inds(A, 1)
    inds(A, 2) == ind || throw(DimensionMismatch("blah blah"))
    @inbounds begin
        for k in ind
            Akkm = A[k,k]
            for (Arow, Acol) in zip(sub(A, k, first:k-1), sub(A, first:k-1, k))
                Akkm -= Arow*Acol'
            end
            Akk = chol!(Akkm, Val{:L})
            A[k,k] = Akk
            AkkInv = inv(Akk)
            Ak = sub(A, :, k)
            for j in ind[first:findfirst(ind, k)-1]  # would be nice to have a notation for this
                Aj = sub(A, :, j)
                c = Aj[k]'*AkkInv'
                for (i, aij) in zip(index(Ak, k+1:end), slice(Aj, k+1:end))
                    if j == first(ind)
                        Ak[i] = Ak[i]*AkkInv'
                    end
                    if j < k
                        Ak[i] -= aij*c
                    end
                end
            end
        end
     end
    return LowerTriangular(A)
end
