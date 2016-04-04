# These are attempts to write code in a future iteration API

function copy!(dest, src)
    for (idest, s) in couple(index(dest), src)
        dest[idest] = s
    end
    dest
end

# Dot product of two vectors (either/both may be sparse)
# Based on `vecdot(x, y)` for arbitrary iterables in linalg/generic
# This implementation has the same problem as reported in #15690.
function vecdot(x::AbstractVector, y::AbstractVector)
    length(x) == length(y) || throw(DimensionMismatch("x and y are of different lengths!"))
    citer = couple(stored(x), stored(y))
    cstate = start(citer)
    done(state) && return dot(zero(eltype(x)), zero(eltype(y)))
    # Otherwise we avoid calling zero
    (vx, vy), cstate = next(citer, cstate)
    s = dot(vx, vy)
    while !done(citer, cstate)
        (vx, vy), cstate = next(citer, cstate)
        s += dot(vx, vy)
    end
    s
end

# Adding two vectors, either/both of which might be sparse.
#
# Note that `similar` is likely just not good enough for this kind of task.
# This is more likely to be a problem with matrices, e.g., knowing that
#    ::Bidiagonal + ::Tridiagonal -> ::Tridiagonal
#    ::Bidiagonal * ::Tridiagonal -> ::Banded
# We may need more promote_op magic.
#
# Here I punt on the "inference problem" and just indicate the output type
# as the first argument.
for op in (:+, :.*)
    @eval begin
        function ($op){Tout<:SparseVector}(::Type{Tout}, x::AbstractVector{Tx}, y::AbstractVector{Ty})
            length(x) == length(y) || throw(DimensionMismatch("x and y are of different lengths!"))
            z = Tout(length(x))  # doesn't exist yet, I think
            for (ix, iy) in couple(index(x), index(y))
                push!(z.nzind, Int(ix))
                push!(z.nzval, $op(x[ix], y[iy]))
            end
            z
        end
    end
end
