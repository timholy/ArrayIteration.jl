# A type to test unconventional indexing ranges

module ATs  # OffsetArrays

using Base: ReshapedArray, ReshapedArrayIterator
using Base.PermutedDimsArrays: PermutedDimsArray
import ArrayIteration: inds

immutable OA{T,N,AA<:AbstractArray} <: AbstractArray{T,N}
    parent::AA
    offsets::NTuple{N,Int}
end

OA{T,N}(A::AbstractArray{T,N}, offsets::NTuple{N,Int}) = OA{T,N,typeof(A)}(A, offsets)

Base.parent(A::OA) = A.parent
Base.size(A::OA) = size(parent(A))
inds(A::OA, d) = (1:size(parent(A),d))+A.offsets[d]
Base.eachindex(A::OA) = CartesianRange(inds(A))

Base.getindex(A::OA, inds::Int...) = parent(A)[offset(A.offsets, inds)...]
Base.setindex!(A::OA, val, inds::Int...) = parent(A)[offset(A.offsets, inds)...] = val

offset{N}(offsets::NTuple{N,Int}, inds::NTuple{N,Int}) = _offset((), offsets, inds)
_offset(out, ::Tuple{}, ::Tuple{}) = out
@inline _offset(out, offsets, inds) = _offset((out..., inds[1]-offsets[1]), Base.tail(offsets), Base.tail(inds))

# An iterator that deliberately makes PermutedDimsArrays more "dangerous"
# (sync to the rescue!)
immutable PDAIterator
    iter::UnitRange{Int}
end
immutable PDAIndex
    i::Int
end

Base.parent(A::PermutedDimsArray) = A.parent # move to Base
Base.eachindex{T,N,AA<:Array}(A::PermutedDimsArray{T,N,AA}) = PDAIterator(eachindex(A.parent))

Base.start(iter::PDAIterator) = start(iter.iter)
Base.next(iter::PDAIterator, s) = ((i, s) = next(iter.iter, s); (PDAIndex(i), s))
Base.done(iter::PDAIterator, s) = done(iter.iter, s)

Base.getindex(A::PermutedDimsArray, i::PDAIndex) = parent(A)[i.i]
Base.setindex!(A::PermutedDimsArray, val, i::PDAIndex) = parent(A)[i.i] = val

# Turn on eachindex for ReshapedArrays
Base.eachindex(A::ReshapedArray) = ReshapedArrayIterator(A)

end
