typealias IterIndex Union{Int,UnitRange{Int},Colon}

# isindex == true  => want the indexes (keys) of the array
# isindex == false => want the values of the array
# isstored == true  => visit only stored entries
# isstored == false => visit all indexes
immutable ArrayIndexingWrapper{A, I<:Tuple{Vararg{IterIndex}}, isindex, isstored}
    data::A
    indexes::I
end

# Internal type for storing instantiated index iterators but returning
# array values
immutable ValueIterator{A<:AbstractArray,I}
    data::A
    iter::I
end

immutable SyncedIterator{I,F<:Tuple{Vararg{Function}}}
    iter::I
    itemfuns::F
end

typealias ArrayOrWrapper Union{AbstractArray,ArrayIndexingWrapper}
typealias AllElements{A,I,isindex} Union{AbstractArray,ArrayIndexingWrapper{A,I,isindex,false}}
typealias StoredElements{A,I,isindex} ArrayIndexingWrapper{A,I,isindex,true}

# storageorder has to be type-stable because it controls the output of
# sync, which is used in iteration
abstract StorageOrder
immutable FirstToLast <: StorageOrder end
immutable OtherOrder{p} <: StorageOrder end
immutable NoOrder <: StorageOrder end  # combination of reshape+permutedims=>undefined

# For iterating over the *values* of an array in column-major order
immutable FirstToLastIterator{N,AA}
    parent::AA
    itr::CartesianRange{N}
end
