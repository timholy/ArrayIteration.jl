### Sparse-array iterators

typealias SubSparseArray{I,T,N,P<:AbstractSparseArray} SubArray{T,N,P,I,false}

## SparseMatrixCSC

typealias SubSparseMatrixCSC{I,T,N,P<:SparseMatrixCSC} SubArray{T,N,P,I,false}
typealias ContiguousCSC{I<:Union{Tuple{Colon,Union{Int,UnitRange{Int}}},Tuple{UnitRange{Int},Int}},T,N,P<:SparseMatrixCSC} Union{P,SubSparseMatrixCSC{I,T,N,P}}

indextype{Tv,Ti}(::Type{SparseMatrixCSC{Tv,Ti}}) = Ti
indextype(A::SparseMatrixCSC) = indextype(typeof(A))

# Indexing along a particular column
immutable IndexCSC
    row::Int; col::Int  # where you are currently (might not be a stored value)
    stored::Bool        # true if this location corresponds to a stored value
    cscindex::Int       # for stored value, the index into rowval & nzval
end

function getindex(I::IndexCSC, d)
    @boundscheck d==1 || d==2 || Base.throw_boundserror(I, d)
    ifelse(d == 1, I.row, I.col)
end

@inline getindex(A::SparseMatrixCSC, i::IndexCSC) = (@inbounds ret = i.stored ? A.nzval[i.cscindex] : zero(eltype(A)); ret)
@inline getindex(A::SubSparseMatrixCSC, i::IndexCSC) = A.parent[i]
# @inline function getindex(a::AbstractVector, i::IndexCSC)
#     @boundscheck 1 <= i.rowval <= length(a)
#     @inbounds ret = a[i.rowval]
#     ret
# end

@inline setindex!(A::SparseMatrixCSC, val, i::IndexCSC) = (@inbounds A.nzval[i.cscindex] = val; val)
@inline setindex!(A::SubSparseMatrixCSC, val, i::IndexCSC) = A.parent[i] = val
# @inline function setindex!(a::AbstractVector, val, i::IndexCSC)
#     @boundscheck 1 <= i.rowval <= length(a) || throw(BoundsError(a, i.rowval))
#     @inbounds a[i.rowval] = val
#     val
# end

immutable IteratorCSC{isstored,S<:ContiguousCSC}
    A::S
    cscrange::UnitRange{Int}

    IteratorCSC(A::SparseMatrixCSC, ::Colon, ::Colon) = new(A, 1:length(A.nzval))
end
IteratorCSC(A::ContiguousCSC, ::Colon, j) = IteratorCSC{false,typeof(A)}(A, Colon(), j)
(::Type{IteratorCSC{E}}){E}(A::ContiguousCSC, ::Colon, j) = IteratorCSC{E,typeof(A)}(A, Colon(), j)

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
# ...but you can choose with ColIteratorCSC{true/false}(A, col)
(::Type{ColIteratorCSC{E}}){E}(A::ContiguousCSC, i, col::Integer) = ColIteratorCSC{E,typeof(A)}(A, i, col)

# Iteration when you're visiting every entry
# The column iterator state has the following structure:
#    (row::Int, nextrowval::Ti<:Integer, cscindex::Int)
# nextrowval = A.rowval[cscindex], but we cache it in the state to
# avoid looking it up each time. We use it to decide when the cscindex
# needs to be incremented.
# The full-matrix iterator is similar, except it adds the column:
#    (row::Int, col::Int, nextrowval::Ti<:Integer, nextcolval::Ti, cscindex::Int)
length(iter::IteratorCSC{false})  = length(iter.A)
length(iter::ColIteratorCSC{false})  = size(iter.A, 1)
function start(iter::IteratorCSC{false})
    cscindex = start(iter.cscrange)
    nextrow, nextcol = _nextrowcolval(iter, 0, cscindex)
    (1, 1, nextrow, nextcol, cscindex)
end
function start(iter::ColIteratorCSC{false})
    cscindex = start(iter.cscrange)
    nextrowval = _nextrowval(iter, cscindex)
    (1, nextrowval, cscindex)
end
done(iter::IteratorCSC{false}, s) = s[2] > size(iter.A, 2)
done(iter::ColIteratorCSC{false}, s) = s[1] > size(iter.A, 1)
function next{S<:SparseMatrixCSC}(iter::IteratorCSC{false,S}, s)
    row, col, nextrowval, nextcolval, cscindex = s
    item = IndexCSC(row, col, row==nextrowval && col==nextcolval, cscindex)
    newrow = row+1
    newcol = col
    if newrow > size(iter.A, 1)
        newrow = 1
        newcol += 1
    end
    if item.stored
        nrv, ncv = _nextrowcolval(iter, col, cscindex+1)
        return (item, (newrow, newcol, nrv, ncv, cscindex+1))
    end
    return (item, (newrow, newcol, nextrowval, nextcolval, cscindex))
end
function next{S<:SparseMatrixCSC}(iter::ColIteratorCSC{false,S}, s)
    row, nextrowval, cscindex = s
    item = IndexCSC(row, iter.col, row==nextrowval, cscindex)
    item.stored ? (item, (row+1, _nextrowval(iter, cscindex+1), cscindex+1)) :
                  (item, (row+1, nextrowval, cscindex))
end
function _nextrowval(iter::ColIteratorCSC, cscindex)
    if cscindex <= last(iter.cscrange)
        return iter.A.rowval[cscindex]
    end
    convert(indextype(iter.A), size(iter.A, 1)+1)  # out-of-bounds fallback
end
function _nextrowcolval(iter::IteratorCSC, col, cscindex)
    if cscindex <= last(iter.cscrange)
        nextcol = col
        nextcscindex = iter.A.colptr[col+1]
        if cscindex >= nextcscindex
            nextcol = findnext(j->j!=nextcscindex, iter.A.colptr, col+1)-1
        end
        return (iter.A.rowval[cscindex], nextcol)
    end
    # out-of-bounds fallback
    convert(indextype(iter.A), size(iter.A, 1)+1), size(iter.A, 2)+1
end


# Iteration when you're visting just the stored entries
# We use similar caching tricks with nextcol and nextcolptrindex for IteratorCSC
length(iter::IteratorCSC{true}) = length(iter.cscrange)
length(iter::ColIteratorCSC{true}) = length(iter.cscrange)
function start(iter::IteratorCSC{true})
    nextcol = findfirst(j->j!=1, iter.A.colptr)-1
    nextcolptrindex = iter.A.colptr[nextcol+1]
    (nextcol, nextcolptrindex, start(iter.cscrange))
end
start(iter::ColIteratorCSC{true}) = start(iter.cscrange)
done(iter::IteratorCSC{true}, s) = done(iter.cscrange, s[3])
done(iter::ColIteratorCSC{true}, s) = done(iter.cscrange, s)
function next{S<:SparseMatrixCSC}(iter::IteratorCSC{true,S}, s)
    @inbounds begin
        col, nextcolptrindex, cscindex = s
        row = iter.A.rowval[cscindex]
    end
    nextcol = col
    if s == nextcolptrindex
        tmp = nextcolptrindex  # work around julia #15276
        nextcol = findnext(j->j!=tmp, iter.A.colptr, col)-1
        nextcolptrindex = iter.A.colptr[nextcol+1]
    end
    idx = IndexCSC(row, col, true, cscindex)
    (idx, (nextcol, nextcolptrindex, cscindex+1))
end
function next{S<:SparseMatrixCSC}(iter::ColIteratorCSC{true,S}, s)
    @inbounds row = iter.A.rowval[s]
    idx = IndexCSC(row, iter.col, true, s)
    (idx, s+1)
end
function next{S<:SubSparseMatrixCSC}(iter::ColIteratorCSC{true,S}, s)
    @inbounds row = iter.A.parent.rowval[s]
    idx = IndexCSC(row, iter.col, true, s)
    (idx, s+1)
end

# nextstored{S<:SparseMatrixCSC}(iter::ColIteratorCSC{S}, s, index::Integer) =

each{A<:SparseMatrixCSC,N,isstored}(w::ArrayIndexingWrapper{A,NTuple{N,Colon},true,isstored}) = IteratorCSC{isstored}(w.data, w.indexes...)
each{A<:SparseMatrixCSC,I,isstored}(w::ArrayIndexingWrapper{A,I,true,isstored}) = ColIteratorCSC{isstored}(w.data, w.indexes...)
each{A<:SparseMatrixCSC,N,isstored}(w::ArrayIndexingWrapper{A,NTuple{N,Colon},false,isstored}) = ValueIterator(w.data, IteratorCSC{isstored}(w.data, w.indexes...))
each{A<:SparseMatrixCSC,I,isstored}(w::ArrayIndexingWrapper{A,I,false,isstored}) = ValueIterator(w.data, ColIteratorCSC{isstored}(w.data, w.indexes...))
