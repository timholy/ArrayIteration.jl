# General API

inds(A::AbstractArray, d) = 1:size(A, d)
inds(A::AbstractArray{T,N}) where {T,N} = ntuple(d->inds(A,d), Val(N))

eachindex(x::ArrayIndexingWrapper) = each(index(x))

function show(io::IO, W::ArrayIndexingWrapper)
    print(io, "iteration hint over ", hint_string(W), " of a ", summary(W.data), " over the region ", W.indexes)
end

function show(io::IO, iter::ContigCartIterator)
    print(io, "Cartesian iterator with:\n  domain ", iter.arrayrange, "\n  start  ", first(iter.columnrange), "\n  stop   ", last(iter.columnrange))
end

parent(W::ArrayIndexingWrapper) = W.data
parent(F::Follower) = F.value

stripwrapper(A::AbstractArray) = A
stripwrapper(A::ArrayIndexingWrapper) = parent(A)

"""
`index(A)`
`index(A, indexes...)`

`index` creates an "iteration hint" that records the region of `A`
that you wish to iterate over. The iterator will return the indexes,
rather than values, of `A`. "iteration hints" are not iterables; to
create an iterator from a hint, call `each` on the resulting object.

In contrast to `eachindex` iteration over a subarray of `A`, the
indexes are for `A` itself.

See also: `value`, `stored`, `each`.
"""
index(w::ArrayIndexingWrapper{A,I,isindex,isstored}) where {A,I,isindex,isstored} = ArrayIndexingWrapper{A,I,true,isstored}(w.data, w.indexes)

"""
`value(A)`
`value(A, indexes...)`

`value` creates an "iteration hint" that records the region of `A`
that you wish to iterate over. The iterator will return the values,
rather than the indexes, of `A`. "iteration hints" are not iterables; to
create an iterator from a hint, call `each` on the resulting object.

See also: `index`, `stored`, `each`.
"""
value(w::ArrayIndexingWrapper{A,I,isindex,isstored}) where {A,I,isindex,isstored} = ArrayIndexingWrapper{A,I,true,isstored}(w.data, w.indexes)

"""
`stored(A)`
`stored(A, indexes...)`

`stored` creates an "iteration hint" that records the region of `A`
that you wish to iterate over. The iterator will return just the
stored values of `A`. "iteration hints" are not iterables; to create
an iterator from a hint, call `each` on the resulting object.

See also: `index`, `value`, `each`.
"""
stored(w::ArrayIndexingWrapper{A,I,isindex,isstored}) where {A,I,isindex,isstored} = ArrayIndexingWrapper{A,I,isindex,true}(w.data, w.indexes)

allindexes(A::AbstractArray{T,N}) where {T,N} = ntuple(d->Colon(),Val(N))

index(A::AbstractArray) = index(A, allindexes(A))
index(A::AbstractArray, I::IterIndex...) = index(A, I)
index(A::AbstractArray{T,N}, indexes::NTuple{N,IterIndex}) where {T,N} = ArrayIndexingWrapper{typeof(A),typeof(indexes),true,false}(A, indexes)

value(A::AbstractArray) = value(A, allindexes(A))
value(A::AbstractArray, I::IterIndex...) = value(A, I)
value(A::AbstractArray{T,N}, indexes::NTuple{N,IterIndex}) where {T,N} = ArrayIndexingWrapper{typeof(A),typeof(indexes),false,false}(A, indexes)

stored(A::AbstractArray) = stored(A, allindexes(A))
stored(A::AbstractArray, I::IterIndex...) = stored(A, I)
stored(A::AbstractArray{T,N}, indexes::NTuple{N,IterIndex}) where {T,N} = ArrayIndexingWrapper{typeof(A),typeof(indexes),false,true}(A, indexes)

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
each(A::AbstractArray{T,N}, indexes::NTuple{N,IterIndex}) where {T,N} = each(ArrayIndexingWrapper{typeof(A),typeof(indexes),false,false}(A, indexes))

# Fallback definitions for each
each(W::ArrayIndexingWrapper{A,I,false,isstored}) where {A,I,isstored} = (itr = each(index(W)); ValueIterator{A,typeof(itr)}(W.data, itr))
each(W::ArrayIndexingWrapper{A,NTuple{N,<:CSlice},true,isstored}) where {A,N,isstored} = eachindex(W.data)
each(W::ArrayIndexingWrapper{A,I,true,isstored}) where {A,I,isstored} = _each(contiguous_index(W.indexes), W)

_each(::Contiguous, W) = contiguous_iterator(W)
_each(::Any, W) = CartesianIndices(ranges(W))

function iterate(vi::ValueIterator, s...)
    v = iterate(vi.iter, s...)
    v === nothing && return v
    idx, s = v
    return vi.data[idx], s
end

function iterate(iter::SyncedIterator, state...)
    v = iterate(iter.iter, state...)
    v === nothing && return v
    item, newstate = v
    mapf(iter.itemfuns, iter.items, item), newstate
end

function iterate(itr::FirstToLastIterator, i=(itr.itr,))
    v = iterate(i...)
    v === nothing && return v
    idx, s = v
    itr.parent[idx], (i[1], s)
end

# SyncedIterator(iter, funcs) = SyncedIterator{typeof(iter), Base.typesof(funcs)}(iter, funcs)

function sync(A::AllElements, B::AllElements)
    checksame_inds(A, B)
    _sync(checksame_storageorder(A, B), A, B)
end

function sync(A::AllElements, B::AllElements...)
    checksame_inds(A, B...)
    _sync(checksame_storageorder(A, B...), A, B...)
end

_sync(::Type{Val{true}}, A, B) = zip(each(A), each(B))
_sync(::Type{Val{false}}, A, B) = zip(columnmajoriterator(A), columnmajoriterator(B))
_sync(::Type{Val{true}}, As...) = zip(map(each, As)...)
_sync(::Type{Val{false}}, As...) = zip(map(columnmajoriterator, As)...)

# For stored, see sync_stored.jl

### Utility methods

"""
`mapf(fs, objs, x)` is similar to `map(f, a, b)`, except instead of mapping one
function over many objects, it maps many function/object pairs over one
`x`. `fs` should be a tuple-of-functions, and `objs` a tuple-of-containers.
"""
mapf(fs::Tuple{Vararg{<:Any,N}}, objs::Tuple{Vararg{<:Any,N}}, x) where N = _mapf((), fs, objs, x)
_mapf(out, ::Tuple{}, ::Tuple{}, x) = out
@inline function _mapf(out, fs, objs, x)
    f, obj = fs[1], objs[1]
    ret = _mapf((out..., f(obj, x)), Base.tail(fs), Base.tail(objs), x)
end

storageorder(::Array) = FirstToLast()
storageorder(::PermutedDimsArray{T,N,AA,perm}) where {T,N,AA,perm} = OtherOrder{perm}()
storageorder(A::ReshapedArray) = _so(storageorder(parent(A)))
storageorder(A::AbstractArray) = storageorder(parent(A)) # parent required!

storageorder(W::ArrayIndexingWrapper) = storageorder(parent(W))

_so(o::FirstToLast) = o
_so(::Any) = NoOrder() # reshape + permutedims => undefined

hint_string(::ArrayIndexingWrapper{A,I,false,false}) where {A,I} = "values"
hint_string(::ArrayIndexingWrapper{A,I,true,false}) where {A,I} = "indexes"
hint_string(::ArrayIndexingWrapper{A,I,false,true}) where {A,I} = "stored values"
hint_string(::ArrayIndexingWrapper{A,I,true,true}) where {A,I} = "indexes of stored values"

ranges(W) = ranges((), W.data, 1, W.indexes...)
ranges(out, A, d) = out
@inline ranges(out, A, d, i, I...) = ranges((out..., i), A, d+1, I...)
@inline ranges(out, A, d, i::CSlice, I...) = ranges((out..., inds(A, d)), A, d+1, I...)

checksame_inds(::Type{Bool}, A::ArrayOrWrapper) = true
checksame_inds(::Type{Bool}, A::ArrayOrWrapper, B::ArrayOrWrapper) = extent_inds(A) == extent_inds(B)
checksame_inds(::Type{Bool}, A, B, C...) = checksame_inds(Bool, A, B) && checksame_inds(Bool, B, C...)
checksame_inds(A) = checksame_inds(Bool, A)
checksame_inds(A, B) = checksame_inds(Bool, A, B) || throw(DimensionMismatch("extent inds $(extent_inds(A)) and $(extent_inds(B)) do not match"))
checksame_inds(A, B, C...) = checksame_inds(A, B) && checksame_inds(B, C...)

# extent_inds drops sliced dimensions
extent_inds(A::AbstractArray) = inds(A)
extent_inds(W::ArrayIndexingWrapper) = _extent_inds((), W.data, 1, W.indexes...)
_extent_inds(out, A, d) = out
@inline _extent_inds(out, A, d, ::Int, indexes...) = _extent_inds(out, A, d+1, indexes...)
@inline _extent_inds(out, A, d, i, indexes...) = _extent_inds((out..., inds(A, d)), A, d+1, indexes...)

# extent_dims indicates which dimensions have extended size
extent_dims(A::AbstractArray{T,N}) where {T,N} = ntuple(identity,Val(N))
extent_dims(W::ArrayIndexingWrapper) = _extent_dims((), 1, W.indexes...)
_extent_dims(out, d::Integer) = out
@inline _extent_dims(out, d, i1::Union{UnitRange{Int},CSlice}, indexes...) = _extent_dims((out..., d), d+1, indexes...)
@inline _extent_dims(out, d, i1, indexes...) = _extent_dims(out, d+1, indexes...)

columnmajoriterator(A::AbstractArray) = columnmajoriterator(IndexStyle(A), A)
columnmajoriterator(::IndexLinear, A) = A
columnmajoriterator(::IndexCartesian, A) = FirstToLastIterator(A, CartesianIndices(size(A)))

columnmajoriterator(W::ArrayIndexingWrapper) = CartesianIndices(ranges(W))

checksame_storageorder(A) = Val{true}
checksame_storageorder(A, B) = _sso(storageorder(A), storageorder(B))
checksame_storageorder(A, B, C...) = checksame_storageorder(_sso(storageorder(A), storageorder(B)), B, C...)
checksame_storageorder(::Type{Val{true}}, A, B...) = checksame_storageorder(A, B...)
checksame_storageorder(::Type{Val{false}}, A, B...) = Val{false}
_sso(::FirstToLast, ::FirstToLast) = Val{true}
_sso(::OtherOrder{p}, ::OtherOrder{p}) where {p} = Val{true}
_sso(::StorageOrder, ::StorageOrder) = Val{false}

# indexes is contiguous if it's one of:
#    Colon...
#    Colon..., Union{UnitRange,Int}, Int...
@inline contiguous_index(I) = contiguous_index(Contiguous(), I...)
@inline contiguous_index(c::Contiguous, ::CSlice, I...) = contiguous_index(c, I...)
@inline contiguous_index(::Contiguous, ::Any, I...) = contiguous_index(MaybeContiguous(), I...)
@inline contiguous_index(c::MaybeContiguous, ::Int, I...) = contiguous_index(c, I...)
@inline contiguous_index(::MaybeContiguous, ::Any, I...) = NonContiguous()
@inline contiguous_index(::Contiguity) = Contiguous()  # won't get here for NonContiguous

contiguous_iterator(W) = _contiguous_iterator(W, IndexStyle(parent(W)))
function _contiguous_iterator(W, ::IndexLinear)
    f, l = firstlast(W)
    f:l
end
_contiguous_iterator(W, ::IndexCartesian) = CartesianIndices(ranges(W))

# Return the "corners" of an iteration range
function firstlast(W)
    A = parent(W)
    f = firstlast(first, A, W.indexes)
    l = firstlast(last, A, W.indexes)
    f, l
end

# This effectively implements 2-argument map, but without allocating
# intermediate tuples
sub2ind = Base._sub2ind
@inline firstlast(f, A, indexes) = sub2ind(size(A), _firstlast((), f, A, indexes...)...)
@inline _firstlast(out, f, A) = out
@inline function _firstlast(out, f, A, i1, indexes...)
    d = length(out)+1
    _firstlast((out..., f(inds(A, d)[i1])), f, A, indexes...)
end
