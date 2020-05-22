const CSlice = Union{Colon,Slice}
const IterIndex = Union{Int,UnitRange{Int},CSlice}

# isindex == true  => want the indexes (keys) of the array
# isindex == false => want the values of the array
# isstored == true  => visit only stored entries
# isstored == false => visit all indexes
struct ArrayIndexingWrapper{A, I<:Tuple{Vararg{IterIndex}}, isindex, isstored}
    data::A
    indexes::I
    function ArrayIndexingWrapper{A,I,IND,STO}(data::A, indexes::I) where {A,I,IND,STO}
        ind = to_slices(indexes, data)
        new{A,typeof(ind),IND,STO}(data, ind)
    end
end

to_slice(::Colon, data, d) = Slice(OneTo(size(data, d)))
to_slice(a, data, d) = a
to_slices(ind::Tuple, data) = tuple(to_slice.(ind, Ref(data), 1:length(ind))...)

# Base.keys(W::ArrayIndexingWrapper) = CartesianIndices(W.indexes)

# Internal type for storing instantiated index iterators but returning
# array values
struct ValueIterator{A<:AbstractArray,I}
    data::A
    iter::I
end

struct SyncedIterator{I,O<:Tuple,F<:Tuple{Vararg{Function}}}
    iter::I
    items::O
    itemfuns::F
end

# declare that an array/iterhint should not control which index
# positions are visited, but only follow the lead of other objects
struct Follower{T}
    value::T
end

const ArrayOrWrapper = Union{AbstractArray,ArrayIndexingWrapper}
const AllElements{A,I,isindex} = Union{AbstractArray,ArrayIndexingWrapper{A,I,isindex,false}}
const StoredElements{A,I,isindex} = ArrayIndexingWrapper{A,I,isindex,true}

# storageorder has to be type-stable because it controls the output of
# sync, which is used in iteration
abstract type StorageOrder end
struct FirstToLast <: StorageOrder end
struct OtherOrder{p} <: StorageOrder end
struct NoOrder <: StorageOrder end  # combination of reshape+permutedims=>undefined

# For iterating over the *values* of an array in column-major order
struct FirstToLastIterator{N,AA}
    parent::AA
    itr::CartesianIndices{N}
end

# Contiguous ranges
abstract type Contiguity end
struct Contiguous <: Contiguity end
struct NonContiguous <: Contiguity end
struct MaybeContiguous <: Contiguity end  # intermediate type used in assessing contiguity

# Contiguous cartesian ranges. Sometimes needed for IndexCartesian arrays.
struct ContigCartIterator{N}
    arrayrange::CartesianIndices{N}
    columnrange::CartesianIndices{N}
end

# Note: sparse types are in sparse.jl
