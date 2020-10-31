@def published = "2020-10-31"
@def title = "Tuples and Vectors, Allocations and Performance for Beginners"
@def authors = "Julius Krumbiegel"
@def rss = "An Intuitive Understanding of Types, Allocations and Performance"
@def rss_pubdate = Date(2020, 10, 31)
@def tags = ["julia"]

# Tuples and Vectors, Allocations and Performance for Beginners

If you're new to Julia, here is a scenario that might have tripped you up already:

Let's define two points. Both are just a collection of two floating point numbers.
But one is a `Vector`, written with the `[]` syntax,  and one a `Tuple`, written with the `()` syntax.

Then we make vectors of both types of points and run a short computation.
Let's see what the performance difference looks like.

```julia
rand_vector_point() = [rand(), rand()] # note the []
rand_tuple_point()  = (rand(), rand()) # note the ()

# create vectors of 500 random points each
vector_points = [rand_vector_point() for _ in 1:500]
tuple_points  = [rand_tuple_point()  for _ in 1:500]

# define a simple function calculating pairwise differences
function difference_matrix(points)
    [p1 .- p2 for p1 in points, p2 in points]
end

# run each version once, just to get compilation out of the way
difference_matrix(vector_points)
difference_matrix(tuple_points)

println("Vector version:")
@time difference_matrix(vector_points)
println("Tuple version:")
@time difference_matrix(tuple_points)
```

```
Vector version:
  0.017412 seconds (250.00 k allocations: 24.796 MiB)
Tuple version:
  0.002698 seconds (2 allocations: 3.815 MiB)
```


The Vector version is much slower than the Tuple version. But why? Are Vectors bad and Tuples good?

In the following post I'll try to explain in simple terms why we see such a big difference
and how you can use your new knowledge to write better code in Julia.

## Allocations

The `@time` outputs show that there were 250,000 allocations for the vector version and only 2 for the tuple version.
What does that mean and why does it make the code slow?

An allocation is a request for memory.
Our program tells the operating system "I need space to store some values" and the operating system gives back the location of some empty space in our RAM we can use.

Asking the operating system for memory takes time, therefore more allocations make our code slower. So far, so good.

In the vector case, this happened 250,000 times, or once for each entry in the 500 x 500 distance matrix.
In the tuple code it happened only twice.

But isn't that weird?

In both cases, each point consists of two floating point numbers.
Each computation generates the exact same number of points.
So why do we need to ask for more memory in the vector version?

This leads us to the next important piece of the puzzle:
We need to look at what the stack and the heap are.

## Stack And Heap

Many programming languages work with two concepts called the _stack_ and the _heap_.
These concepts are just two different ways of organizing memory, which influence the speed with which programs run.

The heap is comparable to a big space where stored objects are scattered all over the place.
Some objects are big, some are small, and there may be large or small gaps between them.
The heap is a bit messy, but it is also spacious.
If you want to store a new object there, the operating system finds a suitable location for you and gives you the address.

The stack on the other hand has a very strict order.
It's like a tower of objects which are stacked neatly in memory, one on top of the other.
There are no gaps between them, and you can't just pull out objects from the middle.
You can only take off the topmost object or stack new ones on top of that one.
New objects are always stored on top, never anywhere else.

Why do we have the two kinds?

The heap is for all objects that can dynamically change in size and for objects that should live longer in memory.
If you need more or less space for some object which is on the heap, you can maybe expand it into some empty space around it, or you have to find a new place and copy it there.
The stack on the other hand can only be built out of objects that never change in size.
Imagine how that neat tower would react if an object right in the middle suddenly shrank or expanded?

That's not allowed.

This might seem restrictive, but on the other hand it makes the stack really fast.
Our program always knows where each object in the stack is and what size it has.
We also never need to ask the operating system for additional memory when storing things on the stack.
That's because we have preallocated memory for it that should be enough for almost all purposes (as long as we don't just keep stacking on top without removing things in between, then you get one of the famed stack overflows).

To sum up, using stack memory is much faster than allocating on the heap.
The problem is that not every object can be stored on the stack, only those that never change in size can be.

How does that relate to our Vectors and Tuples?
It's simple: Vectors are mutable and Tuples are not.

## Mutable And Immutable Objects

At first glance, the two descriptions of a point `[rand(), rand()]` and `(rand(), rand())` might look really similar, and obviously we could run the same function with both versions.
The difference is that the `Vector` created with `[]` is mutable, and the `Tuple` created with `()` is immutable.

For example this works:

```julia
vector_point = [1.0, 2.0]
push!(vector_point, 3.0)
```

```
3-element Array{Float64,1}:
 1.0
 2.0
 3.0
```

And this doesn't:

```julia
tuple_point = (1.0, 2.0)
push!(tuple_point, 3.0)
```

```
ERROR: MethodError: no method matching push!(::Tuple{Float64,Float64}, ::Float64)
```

Another important difference is the exact type of each object.
The vector point is of type `Array{Float64,1}`, or a one-dimensional array of `Float64`s.
The tuple point is of type `Tuple{Float64,Float64}`, or a tuple of exactly two `Float64`s.

Notice the difference? The tuple type guarantees that there are always exactly two elements in our point.
The `Array{Float64,1}` makes no such guarantee.

In Julia, a generic function has a method compiled for each combination of specific types of input arguments that we give it.
So the method of `difference_matrix(points)` where `points` is a Vector of points of type `Array{Float64,1}` doesn't know
how many elements such points have, or how much memory will be needed for the resulting points, or even the matrix storing these points.
That all has to be determined dynamically. Dynamic is slow!

When the compiler compiles the method of `difference_matrix(points)` that uses `points` of type `Tuple{Float64, Float64}`, it has so much more information.
It knows that each point has a specific width in memory.
It knows that for each subtraction operation, the exact same size will be needed on the stack.
It also knows that the resulting Matrix of points can be stored contiguously in memory.

Contiguous means packed tightly together.
We can do that with the tuple points because again we know their size beforehand.
With the vector points, we don't know that.
The matrix that stores our vector points actually only stores the addresses for each of the little mutable point vectors.
These vectors are then scattered all over the heap, with no guaranteed order that the computer could make use of.
This should strike you as a really messy way of dealing with a simple matrix of points, and you would be right.
The array of tuples where all points are packed together like sardines is much better.

Notice that the matrix of tuples itself is not stored on the stack, but is stored in contiguous fashion on the heap.
As long as we only need one allocation for that big piece of memory, that cost disappears compared to the computations we do with that memory.
The 250,000 allocations in the vector case come from each individual `Vector` that results from the subtraction of two existing `Vectors`.
For the matrix that stores the addresses of those individual vectors we again need only one allocation, because the memory addresses of mutable objects are themselves immutable objects of fixed size...

## It's Not Just Tuples

The mechanism explained above is not specific to tuples.
It works with basically every immutable data structure that has a fixed size in memory given its type.
For example, we could define a point as an immutable struct containing exactly two `Float64`s and would enjoy similar benefits:

```julia
struct Point
    x::Float64
    y::Float64
end
```

Actually, such a point would have the exact same memory footprint as a `Tuple{Float64,Float64}` and the compiler might even treat them exactly the same on a machine code level.

The important thing is that the type of our point gives the compiler complete information about the size in memory.
Often, the compiler depends on knowing the exact type of objects that are stored in a collection.
And it's not immediately better just because that type is a `Tuple`.

For example, you can store points of type `Tuple{Float64, Float64}` in a vector with parametric type `Tuple{Any,Any}`.
This basically hides the true identity of our points from the compiler and results in abysmal performance:

```julia
anytuple_points  = Tuple{Any,Any}[rand_tuple_point()  for _ in 1:500]

println("We have hidden our points in an $(typeof(anytuple_points))")

difference_matrix(anytuple_points)

println("AnyTuple version:")
@time difference_matrix(anytuple_points)
```
```
We have hidden our points in an Array{Tuple{Any,Any},1}
AnyTuple version:
  0.109928 seconds (1.75 M allocations: 68.680 MiB, 8.43% gc time)
```

The instructions the compiler created for `Tuple{Any,Any}` points are much more bloated, because who knows what those tuples contain? Could it be `Float64`s by chance?
The issue above actually leads to a very important concept in Julia called _type stability_ which is another huge factor influencing performance, but is too much for this post.

## Stack Those Immutables

To conclude this introduction, always check that your types are as concrete as possible, that your data structures can be represented by pure bit patterns and stored on the stack if possible.
The function `isbits` helps to figure out if your objects have those desired properties.
For example, `isbits([1, 2]) == false` but `isbits((1, 2)) == true`.

You might never really have encountered immutable data structures if you come from languages like R or Matlab, but they are a big reason why Julia code can be so much faster, so make use of them!
If you deal with data structures of known size, preferably use tuples or immutable structs (or check out `StaticArrays.jl`, which has tuples dressed up as arrays for convenience).

You'll make your compiler's and therefore your computer's job much easier, and end up with more efficient and fast code in the process.

This is also not nearly all there is to say about the difference between Tuples and Vectors, but it should hopefully get some of the biggest misconceptions out of the way!
