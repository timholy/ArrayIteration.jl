# ArrayIteration

[![Build Status](https://travis-ci.org/timholy/ArrayIteration.jl.svg?branch=master)](https://travis-ci.org/timholy/ArrayIteration.jl)

This repository contains a candidate next-generation interface for handling arrays in the Julia programming language.
Its two (interconnected) advantages are:
(1) it relaxes many of the assumptions built in to Julia's current array API;
(2) it employs greater [indirection](https://en.wikipedia.org/wiki/Indirection) to create new opportunities for both performance and flexibility.

In particular, ArrayIteration relaxes the following assumptions:

- array dimensions are indexed from `1:size(A,d)`;
- arrays are stored in "column major" order (first-to-last dimension order);
- linear and/or Cartesian indexing is the most efficient way to access elements of the array;
- for generic code that must support any kind of `AbstractArray`, one has no choice but to visit all elements (aka, generic sparse array handling).

At the time of this writing, the first three relaxations can be handled quite comfortably; the last is still missing substantial components.

# API summary

There are only a handful of new functions.

## inds

`inds(A, d)` returns a `UnitRange{Int}` specifying the indexes for dimension `d`.  The default value is `1:size(A, d)`, but you can override this for specific array types.  See the `OA` (for `OffsetArray`) [type definition](test/array_types.jl) for an example.

## sync

`for (a, b) in sync(A, B)` is similar to `zip`, but adds the extra constraint that `a` and `b` are corresponding elements in `A` and `B` whereas `zip` employs independent iterators.
`sync` makes it possible to specify that a particular array type has a most efficient access pattern that may or may not be consistent with efficient patterns for other array types; a simple example is row-major arrays vs column-major arrays, for which cache-efficiency dictates that each would ideally be accessed in its order of memory storage.
When arrays with different preferred access patterns are `sync`ed, it will choose a common access pattern that makes sure the two remain consistent.

## iterator hints: `index`, `value`, `stored`, and `each`

Some algorithms benefit from being able to iterate along a particular dimension of an array; many of the algorithms of linear algebra, from matrix-multiplication to factorizations, fall into this category.

However, some iterators are expensive to construct: for example, to construct an efficient iterator that visits a range of rows within a column of a sparse matrix, one must search a vector of indexes.
However, if this iteration is to occur inside a `sync` block, the time spent constructing this iterator might be wasted if `sync` overrides the most-efficient access pattern in favor of one that is more easily synchronized with some other iterator.
One way to solve this problem is through the creation of "iterator hints," types that store user choices without performing detailed computation.
`sync` "takes" these iterator hints and converts them into actual iterators; in cases where no synchronization is required, `each` performs this task on an array-by-array basis.
(The name is a pun on `eachindex`, as `each(index(A))` is equivalent to `eachindex(A)`. `each` "takes" the iteration-hint provided by `index` and converts it into an actual iterable.)

There are three functions to create iterator hints: `index` (which will result in iteration over the indexes of an array), `value` (for iteration over the entries of `A`), and `stored` (for visiting just the "stored" indexes/values of a sparse array).
They have a common syntax, either `index(A)` (to return indexes of the whole array `A`), or `index(A, 3:7, j)` to visit rows `3:7` of the `j`th column of `A`.  When iterating, the return is a single index for accessing elements: in other words,

```jl
for I in each(index(A, :, j))
    s += A[I]
end
```
will sum the chosen values in the `j`th column of `A`.
(Note the use of the single index `I`, rather than `A[i, j]`.)
That same code could have alternatively been written

```jl
for a in each(value(A, :, j))
    s += a
end
```

or even using the special shortcut `for a in each(A, :, j)`.

The advantage of this syntax is that it allows customization of the particular iterator: for example, with a `ReshapedArray`, the most efficient iterator is one which references the parent array, not the reshaped array.

Likewise, if one wanted to efficiently support sparse arrays, then it might be better to write this as

```jl
for a in each(stored(A, :, j))
    s += a
end
```
since only the stored (non-zero) elements of `A` contribute to the sum.  You can combine `stored` with other hints, for example

```jl
for I in each(index(stored(A, :, j)))
    s += A[I]
end
```
if you needed to have the corresponding index.

For an array with high sparsity, `stored` can result in huge efficiency gains; thanks to multiple dispatch, this should come without cost for handling dense arrays.

It's worth noting that, in contrast with `SubArray`s, the indexes returned from `index` correspond to the "original" array rather than "shifted" indexes for the `SubArray`.  This can help when synchronizing operations across different arrays.

Naturally, one does not have to iterate over just columns or the entire array: `index`, `value`, and `stored` support any "Cartesian" range, and not just those consistent with the conventional `1:size(A,d)` range.

## Status

This API should be fairly well supported, except that `sync(stored(A, ...), ...)` is still essentially missing.

## Credits

In https://github.com/JuliaLang/julia/issues/15648, many useful points were made that influenced the current design of this framework.
