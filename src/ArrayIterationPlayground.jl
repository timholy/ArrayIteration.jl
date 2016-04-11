module ArrayIterationPlayground

using Base: ViewIndex
import Base: getindex, setindex!, start, next, done, eachindex

export inds, index, stored, each

# General API

inds(A::AbstractArray, d) = 1:size(A, d)
inds{T,N}(A::AbstractArray{T,N}) = ntuple(d->inds(A,d), Val{N})

immutable ValueIterator{I}
    iter::I
end
start(iter::ValueIterator) = start(iter.iter)
done(iter::ValueIterator, s) = done(iter.iter, s)
next(iter::ValueIterator, s) = ((item, s) = next(iter.iter, s); (value(iter.iter, item), s))

eachindex(x...) = each(index(x...))

# isindex == true  => want the indexes (keys) of the array
# isindex == false => want the values of the array
# isstored == true  => visit only stored entries
# isstored == false => visit all indexes
immutable ArrayIndexingWrapper{A, I<:Tuple{Vararg{ViewIndex}}, isindex, isstored}
    data::A
    indexes::I
end

index{A,I,isindex,isstored}(w::ArrayIndexingWrapper{A,I,isindex,isstored}) = ArrayIndexingWrapper{A,I,true,isstored}(w.data, w.indexes)
stored{A,I,isindex,isstored}(w::ArrayIndexingWrapper{A,I,isindex,isstored}) = ArrayIndexingWrapper{A,I,isindex,true}(w.data, w.indexes)

allindexes{T,N}(A::AbstractArray{T,N}) = ntuple(d->Colon(),Val{N})

index(A::AbstractArray) = index(A, allindexes(A))
index(A::AbstractArray, I::ViewIndex...) = index(A, I)
index{T,N}(A::AbstractArray{T,N}, indexes::NTuple{N,ViewIndex}) = ArrayIndexingWrapper{typeof(A),typeof(indexes),true,false}(A, indexes)

stored(A::AbstractArray) = stored(A, allindexes(A))
stored(A::AbstractArray, I::ViewIndex...) = stored(A, I)
stored{T,N}(A::AbstractArray{T,N}, indexes::NTuple{N,ViewIndex}) = ArrayIndexingWrapper{typeof(A),typeof(indexes),false,true}(A, indexes)

each(A::AbstractArray, indexes...) = ValueIterator(each(index(A, indexes)))

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
