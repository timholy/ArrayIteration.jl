# optimized methods for ReshapedArrays
function cartesian(a::CartesianIndex{N}, b::CartesianIndex{N}) where N
    CartesianIndices(UnitRange.(a.I, b.I))
end

# column iteration
@inline function iterate(iter::ContigCartIterator, state=first(iter.columnrange))
    state === CartesianIndex() && return nothing
    isless(last(iter.columnrange), state) && return nothing
    v = iterate(iter.arrayrange, state)
    newstate = v === nothing ? CartesianIndex() : v[2]
    ReshapedIndex(state), newstate
end

function _contiguous_iterator(W::ArrayIndexingWrapper{AA}, ::IndexCartesian) where AA<:ReshapedArray
    fi, li = firstlast(W)
    A = parent(W)
    ax = axes(parent(A))
    f = Base.ind2sub_rs(ax, A.mi, fi)
    l = Base.ind2sub_rs(ax, A.mi, li)
    c = ContigCartIterator(CartesianIndices(inds(parent(A))),
                           cartesian(CartesianIndex(f), CartesianIndex(l)))
end

import Base: ==
function ==(a::C, b::C) where C<:ContigCartIterator
    a.arrayrange == b.arrayrange && a.columnrange == b.columnrange
end

# Branching implementation
# @inline isless(I1::CartesianIndex{N}, I2::CartesianIndex{N}) where N = _isless(I1.I, I2.I)
# @inline function _isless(I1::NTuple{N,Int}, I2::NTuple{N,Int}) where N
#     i1, i2 = I1[N], I2[N]
#     isless(i1, i2) && return true
#     isless(i2, i1) && return false
#     _isless(Base.front(I1), Base.front(I2))
# end
# _isless(::Tuple{}, ::Tuple{}) = false

# Select implementation
# @inline isless(I1::CartesianIndex{N}, I2::CartesianIndex{N}) where N = _isless(0, I1.I, I2.I)
# @inline function _isless(ret, I1::NTuple{N,Int}, I2::NTuple{N,Int}) where N
#     newret = ifelse(ret==0, icmp(I1[N], I2[N]), ret)
#     _isless(newret, Base.front(I1), Base.front(I2))
# end
# _isless(ret, ::Tuple{}, ::Tuple{}) = ifelse(ret==1, true, false)
# icmp(a, b) = ifelse(isless(a,b), 1, ifelse(a==b, 0, -1))
