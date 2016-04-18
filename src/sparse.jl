### Sparse-array iterators

## SparseMatrixCSC

typealias SubSparseMatrixCSC{I,T,N,P<:SparseMatrixCSC} SubArray{T,N,P,I,false}
typealias ContiguousCSC{I<:Tuple{Union{Colon,UnitRange{Int}},Any},T,N,P<:SparseMatrixCSC} Union{P,SubSparseMatrixCSC{I,T,N,P}}

indextype{Tv,Ti}(::Type{SparseMatrixCSC{Tv,Ti}}) = Ti
indextype(A::SparseMatrixCSC) = indextype(typeof(A))

# Indexing along a particular column
immutable ColIndexCSC
    row::Int       # where you are currently (might not be stored)
    stored::Bool   # true if this represents a stored value
    cscindex::Int  # for stored value, the index into rowval & nzval
end

@inline getindex(A::SparseMatrixCSC, i::ColIndexCSC) = (@inbounds ret = i.stored ? A.nzval[i.cscindex] : zero(eltype(A)); ret)
@inline getindex(A::SubSparseMatrixCSC, i::ColIndexCSC) = A.parent[i]
# @inline function getindex(a::AbstractVector, i::ColIndexCSC)
#     @boundscheck 1 <= i.rowval <= length(a)
#     @inbounds ret = a[i.rowval]
#     ret
# end

@inline setindex!(A::SparseMatrixCSC, val, i::ColIndexCSC) = (@inbounds A.nzval[i.cscindex] = val; val)
@inline setindex!(A::SubSparseMatrixCSC, val, i::ColIndexCSC) = A.parent[i] = val
# @inline function setindex!(a::AbstractVector, val, i::ColIndexCSC)
#     @boundscheck 1 <= i.rowval <= length(a) || throw(BoundsError(a, i.rowval))
#     @inbounds a[i.rowval] = val
#     val
# end

immutable ColIteratorCSC{isstored,S<:ContiguousCSC}
    A::S
    col::Int
    cscrange::UnitRange{Int}

    function ColIteratorCSC(A::SparseMatrixCSC, ::Colon, col::Integer)
        @boundscheck 1 <= col <= size(A, 2) || throw(BoundsError(A, (:,col)))
        @inbounds r = A.colptr[col]:A.colptr[col+1]-1
        new(A, col, r)
    end
    function ColIteratorCSC{I<:Tuple{Colon,Any}}(A::SubSparseMatrixCSC{I}, ::Colon, col::Integer)
        @boundscheck 1 <= col <= size(A, 2) || throw(BoundsError(A, (:,col)))
        @inbounds j = A.indexes[2][col]
        @inbounds r = A.parent.colptr[j]:A.parent.colptr[j+1]-1
        new(A, col, r)
    end
    function ColIteratorCSC{I<:Tuple{UnitRange{Int},Any}}(A::SubSparseMatrixCSC{I}, ::Colon, col::Integer)
        @boundscheck 1 <= col <= size(A, 2) || throw(BoundsError(A, (:,col)))
        @inbounds j = A.indexes[2][col]
        @inbounds r1, r2 = Int(A.parent.colptr[j]), Int(A.parent.colptr[j+1]-1)
        rowval = A.parent.rowval
        i = A.indexes[1]
        r1 = searchsortedfirst(rowval, first(i), r1, r2, Forward)
        r1 <= r2 && (r2 = searchsortedlast(rowval, last(i), r1, r2, Forward))
        new(A, col, r1:r2)
    end
    function ColIteratorCSC(A::SparseMatrixCSC, i::UnitRange, col::Integer)
        @boundscheck 1 <= col <= size(A, 2) || throw(BoundsError(A, (i,col)))
        @boundscheck (1 <= first(i) && last(i) <= size(A, 1)) || throw(BoundsError(A, (i,col)))
        @inbounds r1, r2 = Int(A.parent.colptr[j]), Int(A.parent.colptr[j+1]-1)
        rowval = A.parent.rowval
        r1 = searchsortedfirst(rowval, first(i), r1, r2, Forward)
        r1 <= r2 && (r2 = searchsortedlast(rowval, last(i), r1, r2, Forward))
        new(A, col, r1:r2)
    end
end
# Default is to visit each site, not just the stored sites
ColIteratorCSC(A::ContiguousCSC, i, col::Integer) = ColIteratorCSC{false,typeof(A)}(A, i, col)
# Choose with ColIteratorCSC{true/false}(A, col)
(::Type{ColIteratorCSC{E}}){E}(A::ContiguousCSC, i, col::Integer) = ColIteratorCSC{E,typeof(A)}(A, i, col)

# Iteration when you're visiting every entry
# The iterator state has the following structure:
#    (row::Int, nextrowval::Ti<:Integer, cscindex::Int)
# nextrowval = A.rowval[cscindex], but we cache it in the state to
# avoid looking it up each time. We use it to decide when the cscindex
# needs to be incremented.
length(iter::ColIteratorCSC{false})  = size(iter.A, 1)
function start(iter::ColIteratorCSC{false})
    cscindex = start(iter.cscrange)
    nextrowval = _nextrowval(iter, cscindex)
    (1, nextrowval, cscindex)
end
done(iter::ColIteratorCSC{false}, s) = s[1] > size(iter.A, 1)
function next{S<:SparseMatrixCSC}(iter::ColIteratorCSC{false,S}, s)
    row, nextrowval, cscindex = s
    item = ColIndexCSC(row, row==nextrowval, cscindex)
    item.stored ? (item, (row+1, _nextrowval(iter, cscindex+1), cscindex+1)) :
                  (item, (row+1, nextrowval, cscindex))
end
_nextrowval(iter::ColIteratorCSC, cscindex) = cscindex <= last(iter.cscrange) ? iter.A.rowval[cscindex] : convert(indextype(iter.A), size(iter.A, 1)+1)

length(iter::ColIteratorCSC{true}) = length(iter.cscrange)
start(iter::ColIteratorCSC{true}) = start(iter.cscrange)
done(iter::ColIteratorCSC{true}, s) = done(iter.cscrange, s)
next{S<:SparseMatrixCSC}(iter::ColIteratorCSC{true,S}, s) = (@inbounds row = iter.A.rowval[s]; idx = ColIndexCSC(row, true, s); (idx, s+1))
next{S<:SubSparseMatrixCSC}(iter::ColIteratorCSC{true,S}, s) = (@inbounds row = iter.A.parent.rowval[s]; idx = ColIndexCSC(row, true, s); (idx, s+1))

# nextstored{S<:SparseMatrixCSC}(iter::ColIteratorCSC{S}, s, index::Integer) =

each{A<:SparseMatrixCSC,I}(w::ArrayIndexingWrapper{A,I,true,false}) = ColIteratorCSC{false}(w.data, w.indexes...)
each{A<:SparseMatrixCSC,I}(w::ArrayIndexingWrapper{A,I,true,true})  = ColIteratorCSC{true}(w.data, w.indexes...)
each{A<:SparseMatrixCSC,I,isstored}(w::ArrayIndexingWrapper{A,I,false,isstored}) = ValueIterator(w.data, ColIteratorCSC{isstored}(w.data, w.indexes...))
