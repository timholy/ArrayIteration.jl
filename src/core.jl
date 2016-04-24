# General API

inds(A::AbstractArray, d) = 1:size(A, d)
inds{T,N}(A::AbstractArray{T,N}) = ntuple(d->inds(A,d), Val{N})

eachindex(x...) = each(index(x...))

function show(io::IO, W::ArrayIndexingWrapper)
    print(io, "iteration hint over ", hint_string(W), " of a ", summary(W.data), " over the region ", W.indexes)
end

parent(W::ArrayIndexingWrapper) = W.data

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
index(A::AbstractArray, I::IterIndex...) = index(A, I)
index{T,N}(A::AbstractArray{T,N}, indexes::NTuple{N,IterIndex}) = ArrayIndexingWrapper{typeof(A),typeof(indexes),true,false}(A, indexes)

stored(A::AbstractArray) = stored(A, allindexes(A))
stored(A::AbstractArray, I::IterIndex...) = stored(A, I)
stored{T,N}(A::AbstractArray{T,N}, indexes::NTuple{N,IterIndex}) = ArrayIndexingWrapper{typeof(A),typeof(indexes),false,true}(A, indexes)

"""
`each(iterhint)`
`each(iterhint, indexes...)`

`each` instantiates the iterator associated with `iterhint`. In
conjunction with `index` and `stored`, you may choose to iterate over
either indexes or values, as well as choosing whether to iterate over
all elements or just the stored elements.
"""
each(A::AbstractArray) = each(A, allindexes(A))
each(A::AbstractArray, indexes::IterIndex...) = each(A, indexes)
each{T,N}(A::AbstractArray{T,N}, indexes::NTuple{N,IterIndex}) = each(ArrayIndexingWrapper{typeof(A),typeof(indexes),false,false}(A, indexes))

# Fallback definitions for each
each{A,I,isstored}(W::ArrayIndexingWrapper{A,I,false,isstored}) = (itr = each(index(W)); ValueIterator{A,typeof(itr)}(W.data, itr))
each{A,N,isstored}(W::ArrayIndexingWrapper{A,NTuple{N,Colon},true,isstored}) = eachindex(W.data)
each{A,I,isstored}(W::ArrayIndexingWrapper{A,I,true,isstored}) = CartesianRange(ranges(W))

start(vi::ValueIterator) = start(vi.iter)
done(vi::ValueIterator, s) = done(vi.iter, s)
next(vi::ValueIterator, s) = ((idx, s) = next(vi.iter, s); (vi.data[idx], s))

start(iter::SyncedIterator) = start(iter.iter)
next(iter::SyncedIterator, state) = mapf(iter.itemfuns, state), next(iter.iter, state)
done(iter::SyncedIterator, state) = done(iter.iter, state)

start(itr::FirstToLastIterator) = (itr.itr, start(itr.itr))
function next(itr::FirstToLastIterator, i)
    idx, s = next(i[1], i[2])
    itr.parent[idx], (i[1], s)
end
done(itr::FirstToLastIterator, i) = done(i[1], i[2])

function sync(A::AllElements, B::AllElements)
    check_sameinds(A, B)
    _sync(storageorder(A), storageorder(B), A, B)
end

_sync(::FirstToLast, ::FirstToLast, A, B) = zip(each(A), each(B))
_sync{p}(::OtherOrder{p}, ::OtherOrder{p}, A, B) = zip(each(A), each(B))
_sync(::StorageOrder, ::StorageOrder, A, B) = zip(columnmajoriterator(A), columnmajoriterator(B))

sync(A::StoredElements, B::StoredElements) = sync_stored(A, B)
sync(A, B::StoredElements) = sync_stored(A, B)
sync(A::StoredElements, B) = sync_stored(A, B)

#function sync_stored(A, B)
#    check_sameinds(A, B)
#end

### Utility methods

"""
`mapf(fs, x)` is similar to `map`, except instead of mapping one
function over many objects, it maps many functions over one
object. `fs` should be a tuple-of-functions.
"""
@inline mapf(fs::Tuple, x) = _mapf((), x, fs...)
_mapf(out, x) = out
@inline _mapf(out, x, f, fs...) = _mapf((out..., f(x)), x, fs...)

storageorder(::Array) = FirstToLast()
storageorder{T,N,AA,perm}(::PermutedDimsArray{T,N,AA,perm}) = OtherOrder{perm}()
storageorder(A::ReshapedArray) = _so(storageorder(parent(A)))
storageorder(A::AbstractArray) = storageorder(parent(A)) # parent required!

storageorder(W::ArrayIndexingWrapper) = storageorder(parent(W))

_so(o::FirstToLast) = o
_so(::Any) = NoOrder() # reshape + permutedims => undefined

hint_string{A,I}(::ArrayIndexingWrapper{A,I,false,false}) = "values"
hint_string{A,I}(::ArrayIndexingWrapper{A,I,true,false}) = "indexes"
hint_string{A,I}(::ArrayIndexingWrapper{A,I,false,true}) = "stored values"
hint_string{A,I}(::ArrayIndexingWrapper{A,I,true,true}) = "indexes of stored values"

ranges(W) = ranges((), W.data, 1, W.indexes...)
ranges(out, A, d) = out
@inline ranges(out, A, d, i, I...) = ranges((out..., i), A, d+1, I...)
@inline ranges(out, A, d, i::Colon, I...) = ranges((out..., inds(A, d)), A, d+1, I...)

check_sameinds(::Type{Bool}, A::ArrayOrWrapper, B::ArrayOrWrapper) = extent_inds(A) == extent_inds(B)
check_sameinds(::Type{Bool}, A, B, C...) = check_sameinds(Bool, A, B) && check_sameinds(Bool, B, C...)
check_sameinds(A, B) = check_sameinds(Bool, A, B) || throw(DimensionMismatch("extent inds $(extent_inds(A)) and $(extent_inds(B)) do not match"))
check_sameinds(A, B, C...) = check_sameinds(A, B) && check_sameinds(B, C...)

# extent_inds drops sliced dimensions
extent_inds(A::AbstractArray) = inds(A)
extent_inds(W::ArrayIndexingWrapper) = _extent_inds((), W.data, 1, W.indexes...)
_extent_inds(out, A, d) = out
@inline _extent_inds(out, A, d, ::Int, indexes...) = _extent_inds(out, A, d+1, indexes...)
@inline _extent_inds(out, A, d, i, indexes...) = _extent_inds((out..., inds(A, d)), A, d+1, indexes...)

columnmajoriterator(A::AbstractArray) = columnmajoriterator(linearindexing(A), A)
columnmajoriterator(::LinearFast, A) = A
columnmajoriterator(::LinearSlow, A) = FirstToLastIterator(A, CartesianRange(size(A)))

columnmajoriterator(W::ArrayIndexingWrapper) = CartesianRange(ranges(W))
