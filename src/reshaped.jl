# optimized methods for ReshapedArrays

# column iteration
start(iter::ContigCartIterator) = iter.columnrange.start
function next(iter::ContigCartIterator, state)
    item, newstate = next(iter.arrayrange, state)
    ReshapedIndex(item), newstate
end
done(iter::ContigCartIterator, state) = isless(iter.columnrange.stop, state)

function _contiguous_iterator{AA<:ReshapedArray}(W::ArrayIndexingWrapper{AA}, ::LinearSlow)
    fi, li = firstlast(W)
    A = parent(W)
    f = Base.ind2sub_rs(A.mi, fi)
    l = Base.ind2sub_rs(A.mi, li)
    ContigCartIterator(CartesianRange(inds(parent(A))),
                       CartesianRange(CartesianIndex(f), CartesianIndex(l)))
end

# Branching implementation
# @inline isless{N}(I1::CartesianIndex{N}, I2::CartesianIndex{N}) = _isless(I1.I, I2.I)
# @inline function _isless{N}(I1::NTuple{N,Int}, I2::NTuple{N,Int})
#     i1, i2 = I1[N], I2[N]
#     isless(i1, i2) && return true
#     isless(i2, i1) && return false
#     _isless(Base.front(I1), Base.front(I2))
# end
# _isless(::Tuple{}, ::Tuple{}) = false

# Select implementation
# @inline isless{N}(I1::CartesianIndex{N}, I2::CartesianIndex{N}) = _isless(0, I1.I, I2.I)
# @inline function _isless{N}(ret, I1::NTuple{N,Int}, I2::NTuple{N,Int})
#     newret = ifelse(ret==0, icmp(I1[N], I2[N]), ret)
#     _isless(newret, Base.front(I1), Base.front(I2))
# end
# _isless(ret, ::Tuple{}, ::Tuple{}) = ifelse(ret==1, true, false)
# icmp(a, b) = ifelse(isless(a,b), 1, ifelse(a==b, 0, -1))
