module ArrayIterationPlayground

using Base: ViewIndex
import Base: getindex, setindex!, start, next, done, length, eachindex, show

export inds, index, stored, each

# General API

inds(A::AbstractArray, d) = 1:size(A, d)
inds{T,N}(A::AbstractArray{T,N}) = ntuple(d->inds(A,d), Val{N})

eachindex(x...) = each(index(x...))

# isindex == true  => want the indexes (keys) of the array
# isindex == false => want the values of the array
# isstored == true  => visit only stored entries
# isstored == false => visit all indexes
immutable ArrayIndexingWrapper{A, I<:Tuple{Vararg{ViewIndex}}, isindex, isstored}
    data::A
    indexes::I
end
show(io::IO, W::ArrayIndexingWrapper) = print(io, "iteration hint over ", hint_string(W), " of a ", summary(W.data), " over the region ", W.indexes)
hint_string{A,I}(::ArrayIndexingWrapper{A,I,false,false}) = "values"
hint_string{A,I}(::ArrayIndexingWrapper{A,I,true,false}) = "indexes"
hint_string{A,I}(::ArrayIndexingWrapper{A,I,false,true}) = "stored values"
hint_string{A,I}(::ArrayIndexingWrapper{A,I,true,true}) = "indexes of stored values"

"""
`index(A)`
`index(A, indexes...)`

`index` creates an "iteration hint" that records the region of `A`
that you wish to iterate over. The iterator will return the indexes,
rather than values, of `A`. "iteration hints" are not iterables; to
create an iterator from a hint, call `each` on the resulting object.

In contrast to `eachindex` iteration over a subarray of `A`, the
indexes are for `A` itself.

See also: `stored`, `each`.
"""
index{A,I,isindex,isstored}(w::ArrayIndexingWrapper{A,I,isindex,isstored}) = ArrayIndexingWrapper{A,I,true,isstored}(w.data, w.indexes)

"""
`stored(A)`
`stored(A, indexes...)`

`stored` creates an "iteration hint" that records the region of `A`
that you wish to iterate over. The iterator will return just the
stored values of `A`. "iteration hints" are not iterables; to create
an iterator from a hint, call `each` on the resulting object.

See also: `index`, `each`.
"""
stored{A,I,isindex,isstored}(w::ArrayIndexingWrapper{A,I,isindex,isstored}) = ArrayIndexingWrapper{A,I,isindex,true}(w.data, w.indexes)

allindexes{T,N}(A::AbstractArray{T,N}) = ntuple(d->Colon(),Val{N})

index(A::AbstractArray) = index(A, allindexes(A))
index(A::AbstractArray, I::ViewIndex...) = index(A, I)
index{T,N}(A::AbstractArray{T,N}, indexes::NTuple{N,ViewIndex}) = ArrayIndexingWrapper{typeof(A),typeof(indexes),true,false}(A, indexes)

stored(A::AbstractArray) = stored(A, allindexes(A))
stored(A::AbstractArray, I::ViewIndex...) = stored(A, I)
stored{T,N}(A::AbstractArray{T,N}, indexes::NTuple{N,ViewIndex}) = ArrayIndexingWrapper{typeof(A),typeof(indexes),false,true}(A, indexes)

"""
`each(iterhint)`
`each(iterhint, indexes...)`

`each` instantiates the iterator associated with `iterhint`. In
conjunction with `index` and `stored`, you may choose to iterate over
either indexes or values, as well as choosing whether to iterate over
all elements or just the stored elements.
"""
each(A::AbstractArray) = each(A, allindexes(A))
each(A::AbstractArray, indexes::ViewIndex...) = each(A, indexes)
each{T,N}(A::AbstractArray{T,N}, indexes::NTuple{N,ViewIndex}) = each(ArrayIndexingWrapper{typeof(A),typeof(indexes),false,false}(A, indexes))

# Internal type for storing instantiated index iterators but returning
# array values
immutable ValueIterator{A<:AbstractArray,I}
    data::A
    iter::I
end

each{A,I,stored}(W::ArrayIndexingWrapper{A,I,false,stored}) = (itr = each(index(W)); ValueIterator{A,typeof(itr)}(W.data, itr))
each{A,I}(W::ArrayIndexingWrapper{A,I,true}) = CartesianRange(ranges(W))

start(vi::ValueIterator) = start(vi.iter)
done(vi::ValueIterator, s) = done(vi.iter, s)
next(vi::ValueIterator, s) = ((idx, s) = next(vi.iter, s); (vi.data[idx], s))

ranges(W) = ranges((), W.data, 1, W.indexes...)
ranges(out, A, d) = out
@inline ranges(out, A, d, i, I...) = ranges((out..., i), A, d+1, I...)
@inline ranges(out, A, d, i::Colon, I...) = ranges((out..., inds(A, d)), A, d+1, I...)


immutable SyncedIterator{I,F<:Tuple{Vararg{Function}}}
    iter::I
    itemfuns::F
end

start(iter::SyncedIterator) = start(iter.iter)
next(iter::SyncedIterator, state) = mapf(iter.itemfuns, state), next(iter.iter, state)
done(iter::SyncedIterator, state) = done(iter.iter, state)

"""
`mapf(fs, x)` is similar to `map`, except instead of mapping one
function over many objects, it maps many functions over one
object. `fs` should be a tuple-of-functions.
"""
@inline mapf(fs::Tuple, x) = _mapf((), x, fs...)
_mapf(out, x) = out
@inline _mapf(out, x, f, fs...) = _mapf((out..., f(x)), x, fs...)

include("sparse.jl")

end # module
