@def published = "2021-06-07 00:00:00 +0000"
@def title = "Julia macros for beginners"
@def authors = "Julius Krumbiegel"
@def rss = "Julia macros for beginners"
@def rss_pubdate = Date(2021, 06, 07)
@def rss_author = "Julius Krumbiegel"
@def tags = ["julia"]

# Julia macros for beginners

Macros are a powerful and interesting feature of the Julia programming language, but they can also be confusing.
Users coming from Python, Matlab or R have not come in contact with similar constructs before, and they require a different way of thinking about code.
This article is supposed to be a simple introduction, after which you might judge better when use of macros is appropriate and how to get around some of the most common gotchas.

## What are macros for?

Macros change existing source code or generate entirely new code.
They are not some kind of more powerful function that unlocks secret abilities of Julia, they are just a way to automatically write code that you could have written out by hand anyway.
There's just the question whether writing that code by hand is practical, not if it's possible.
Often, we can save users a lot of work, by hiding boilerplate code they would otherwise need to write inside our macro.

Still, it's good advice, especially for beginners, to think hard if macros are the right tool for the job, or if run-of-the-mill functions serve the same purpose.
Often, functions are preferable because macro magic puts a cognitive burden on the user, it makes it harder to reason about what code does.
Before understanding the code, they have to understand the transformation that the macro is doing, which often goes hand in hand with non-standard syntax.
That is, unless they are ok with their code having unintended consequences.

## What does a macro do?

Some of the magic of macros derives from the fact that they don't just generate some predefined code, they rather take the code they are applied to and transform it in useful ways.
Variable names are one of the fundamental mechanisms by which we make code understandable for humans.
In principle, you could replace every identifier in a working piece of code with something random, and it would still work.

```julia
profit = revenue - costs
# does the same thing as
hey = whats - up
```
The computer doesn't care about the names, only humans do.
But functions run after the code has been transformed into lower-level representations, and names are lost at that point.

For example, in this code snippet, there is no way for the author of the function to know what the user named their variable.
The function just receives a value, and as far as it is concerned, that value is named `x`.

```julia
function show_value(x)
    println("The value you passed is ", x)
end

orange = "sweet"
apple = "sour"

show_value(orange)
show_value(apple)
```

```
The value you passed is sweet
The value you passed is sour

```

Any information about what the user wrote is lost, as the function only knows "sweet" and "sour" were passed.
If we want to incorporate the information contained in the variable names, we need a macro.

```julia
macro show_value(variable)
    quote
        println("The ", $(string(variable)), " you passed is ", $(esc(variable)))
    end
end

@show_value(orange)
@show_value(apple)
```

```
The orange you passed is sweet
The apple you passed is sour

```

You probably know a macro that works very similar to this one, which is `@show`

```julia
@show orange
@show apple
nothing # hide
```

```
orange = "sweet"
apple = "sour"

```

Note that it doesn't make a difference here if we use parentheses for the macros or not.
That's a feature of Julia's syntax which makes some macros more tidy to write.
This is especially true if the macro precedes a for block or some other multi-line expression.

## How do macros work?

Let's look at our macro in more detail. Even though it's short, it has a few interesting aspects to it.

First of all, a macro runs before any code is executed.
Therefore, you never have access to any runtime values in a macro.
That's something that trips many beginners up, but is crucial to understand.
All the logic in the macro has to happen only using the information you can get from the expressions that the macro is applied to.

One good step to understand what's going on with an expression, is to dump it.
You can use `Meta.@dump` for that.

In our case, it's not very interesting:

```julia
Meta.@dump orange
```

```
Symbol orange

```

As you can see, the expression `orange` contains only the `Symbol` orange.
So that is what our macro gets as input, just `:orange`.
But, again, no runtime information about it being `"sweet"`.

Inside the macro, a `quote` expression is constructed.
A `quote` with source code inside returns an expression object that describes this code.
The expression we return from a macro is spliced into the place where the macro call happens, as if you really had written the macro result there.
That's the reason why a macro can't technically do more than any old Julia code.

We can see the code that the macro call results in by using another helper macro, `@macroexpand`.

```julia
@macroexpand @show_value orange
```

```
quote
    #= string:3 =#
    Main.##345.println("The ", "orange", " you passed is ", orange)
end
```

You can see that, ignoring linenumber and module information, the macro created a function call as if we had written

```julia
println("The ", "orange", " you passed is ", orange)
```

Therefore, let's look at where the two oranges come from.

The first one is `"orange"`, which is a string literal.
We achieved this with this expression inside the macro:

```julia
$(string(variable))
```

Remember that `variable` holds the `Symbol` `:orange` when the macro is called.
We convert that to a string and then place that string into the quoted expression using the interpolation symbol `$`.
This is how we can print out a sentence that references the user's chosen variable name.

The other `orange` is just a normal variable name.
It was created with the interpolation expression `$(esc(variable))`.
The `esc` stands for `escape` and is another part of macros that is hard to understand for beginners.

## What's escaping?

To explain why `esc` needed, let's look at a macro that leaves it out.
In this example we define the macro in a separate module (because any macro you'd put in a package would not be in the `Main` module either):

```julia
module SomeModule
    export @show_value_no_esc
    macro show_value_no_esc(variable)
        quote
            println("The ", $(string(variable)), " you passed is ", $variable)
        end
    end
end

using .SomeModule

try
    @show_value_no_esc(orange)
catch e
    sprint(showerror, e)
end
```

```
"UndefVarError: orange not defined"
```

The code errors because there is no variable `orange`.
But there should be, we interpolated it right there!
Let's look at the macro output with `@macroexpand` again:

```julia
@macroexpand @show_value_no_esc(orange)
```

```
quote
    #= string:5 =#
    Main.##345.SomeModule.println("The ", "orange", " you passed is ", Main.##345.SomeModule.orange)
end
```

Ok, so the variable looked up is actually `SomeModule.orange`, and of course we didn't define a variable with that name in `SomeModule`.
The reason this happens is that macros do often need to reference values from whatever module they were defined in.
For example, to add a helper function that also lives in that module to the user's code.
Any variable name used in the created expression is looked up in the macro's parent module by default.

The other reason is that it is potentially dangerous to just change or create variables in user space in a macro that knows nothing about what's going on there.

Imagine the writer of the macro and the user as two people who know nothing about each other.
They only interface via the small snippet of code passed to the macro.
So, obviously, the macro shouldn't mess around with the user's variables.

In theory, a macro could insert things like `my_variable = nothing` or `empty!(some_array)` in the place where it's used.
But imagine the user already has a `my_variable` and it happens to hold the result of a computation that ran hours.
As the macro writer doesn't know anything about the variables the user has created, all macro-created variables are by default scoped to the macro's module to avoid conflicts.

Here's a short example of bad escaping, with a macro that is not really supposed to do anything:

```julia
macro change_nothing(exp)
    e = quote
        temp_variable = nothing # this could be some intermediate computation
        $exp # we actually just pass the input expression back unchanged
    end
    esc(e) # but everything is escaped
end

# a user who happens to have a temp variable calls this macro...

temp_variable = "important information"
x = @change_nothing 1 + 1

@show x
@show temp_variable
nothing # hide
```

```
x = 2
temp_variable = nothing

```

Whoops, the `temp_variable` was overwritten by the macro, and this can happen with badly written macros.

But still, in order to access the value of the user's variable `orange`, we need to `escape` the use of that symbol in our generated expression.
Escaping the variable could be summarized as saying "treat this variable like a variable the user has written themselves".

As a rule of thumb, macros should only ever escape variables that they know about because they were passed to the macro.
These are the variables that the user potentially wants to have changed by the macro, or at least they are aware that they could be subject to change.

Here you can see another example, where there is both a user and a module orange:

```julia
module AnotherModule
    export @show_value_user_and_module

    orange = "bitter"

    macro show_value_user_and_module(variable)
        quote
            println("The ", $(string(variable)), " you passed is ", $(esc(variable)),
                " and the one from the module is ", $variable)
        end
    end
end

using .AnotherModule

@show_value_user_and_module orange
```

```
The orange you passed is sweet and the one from the module is bitter

```

## Modifying expressions

Even though we could already see some interesting macro properties, maybe you didn't start reading this article to learn about printing users their own variable names back (even though that is a very user friendly behavior in general, and many R users like their non-standard evaluation a lot for this reason).

Usually, you want to modify the expression you receive, or build a new one with it, to achieve some functional purpose.
Sometimes, macros are used to define domain specific languages or DSLs, that allow users to specify complex things with simple, yet non-standard expressions.

A good example for this are the formulas from `StatsModels.jl`, where `@formula(y ~ x)` is a nice shortcut to create a formula object that you could in principle build yourself without a macro, but with much more typing.

Let's try to write a small useful macro that transforms a real expression!

An issue some Julia users face once in a while, is that the `fill` function's argument is executed once, and then the whole vector is filled with that result.
Let's say we want a vector of 5 three-element random vectors.

```julia
rand_vec = fill(rand(3), 5)
```

```
5-element Vector{Vector{Float64}}:
 [0.6812848357202166, 0.4029451418936725, 0.6175275330130934]
 [0.6812848357202166, 0.4029451418936725, 0.6175275330130934]
 [0.6812848357202166, 0.4029451418936725, 0.6175275330130934]
 [0.6812848357202166, 0.4029451418936725, 0.6175275330130934]
 [0.6812848357202166, 0.4029451418936725, 0.6175275330130934]
```

As you can see, every vector is the same, which we don't want.
A way to get our desired result is with a list comprehension:

```julia
rand_vec = [rand(3) for _ in 1:5]
```

```
5-element Vector{Vector{Float64}}:
 [0.49019315470583913, 0.34278729269778063, 0.9397324805200158]
 [0.8550409141676747, 0.10951003155142769, 0.5868983985077327]
 [0.21187936828897747, 0.8734015984778174, 0.7339785144559376]
 [0.9014223088150919, 0.3676390393951927, 0.7322306471315203]
 [0.09559583305483077, 0.6050374787289248, 0.6993212571694867]
```

This works, but the fill syntax is so nice and short in comparison.
Also it gets even worse if you are iterating multiple dimensions in nested for loops, while you can always write `fill(rand(3), 3, 4, 5)`.

So can we write a macro that makes a list comprehension expression out of a call like `@fill(rand(3), 5)`, so that the first argument is executed anew in each iteration?
Let's try it!

The first step is always to understand what expression you're even trying to build.
We already use two iterators here to understand how multiple are handled in the resulting expression:

```julia
Meta.@dump [rand(3) for _ in 1:5, _ in 1:3]
```

```
Expr
  head: Symbol comprehension
  args: Array{Any}((1,))
    1: Expr
      head: Symbol generator
      args: Array{Any}((3,))
        1: Expr
          head: Symbol call
          args: Array{Any}((2,))
            1: Symbol rand
            2: Int64 3
        2: Expr
          head: Symbol =
          args: Array{Any}((2,))
            1: Symbol _
            2: Expr
              head: Symbol call
              args: Array{Any}((3,))
                1: Symbol :
                2: Int64 1
                3: Int64 5
        3: Expr
          head: Symbol =
          args: Array{Any}((2,))
            1: Symbol _
            2: Expr
              head: Symbol call
              args: Array{Any}((3,))
                1: Symbol :
                2: Int64 1
                3: Int64 3

```

Aha, now we actually see some real expressions.
Every `Expr` object has a `head` that stores what kind of expression it is, and a vector called `args` which contains all arguments to that expression.

We can see that a list comprehension is made by making an `Expr` where the head is `:comprehension`.
There's only one argument to that expression, which is a :generator expression.
This one in turn is assembled of the expression being called in each iteration, and the iteration expressions `_ = 1:5` and `_ = 1:3`.

We want to use the syntax `@fill(rand(3), sizes...)`, so we need to think how we can transform those two arguments into the expression we want.

Here, we'll build the `Expr` by hand, instead of writing one big `quote`.
Sometimes that is easier, it also depends on what you find more readable.
Expressions with a lot of quoting and interpolating can be hard to understand.
I usually prefer `quote ... end` over the equivalent `:(...)` just because I can parse words a bit better than parentheses.

Here we go:

For each size argument, we make one of the iterator expressions that we saw in the dump above.
We escape each size variable `s` because those are the arguments that the user will write themselves, and they need to resolve correctly in their scope later.

The comprehension expression then receives the first argument escaped because that expression also needs to run as-is in the user's scope.

```julia
macro fill(exp, sizes...)

    iterator_expressions = map(sizes) do s
        Expr(
            :(=),
            :_,
            quote 1:$(esc(s)) end
        )
    end

    Expr(
        :comprehension,
        esc(exp),
        iterator_expressions...
    )
end
```

```
@fill (macro with 1 method)
```

Let's try it out:

```julia
@fill(rand(3), 5)
```

```
5-element Vector{Vector{Float64}}:
 [0.1139113373998224, 0.3573470989058838, 0.4386214468752223]
 [0.1509185991824915, 0.7155213148212995, 0.9799036243798529]
 [0.5343541641851779, 0.006877254139170619, 0.33470902481149567]
 [0.8011467320748902, 0.6785417555929447, 0.3549453187879492]
 [0.734276208322437, 0.893731178943594, 0.8288924117876237]
```

A good check if you've escaped correctly is to pass expressions that reference some local variables.
The call will error if you've forgotten to escape any of them:

```julia
n = 3
k = 5

@fill(rand(n), k)
```

```
5-element Vector{Vector{Float64}}:
 [0.4469838582877874, 0.7998077151200393, 0.18358119718987465]
 [0.6888585634220834, 0.7567563653659923, 0.9326624004544035]
 [0.6764494427437526, 0.6575388834261413, 0.9856806991262359]
 [0.25283883620967096, 0.46747585157183225, 0.5292280679523935]
 [0.5216051998736333, 0.17855087440498796, 0.5920478781909175]
```

This works fine!
It should also work with more size arguments, we'll generate only random scalars so the printout is manageable:

```julia
@fill(rand(), 5, 3)
```

```
5×3 Matrix{Float64}:
 0.352458  0.461203  0.0771023
 0.75737   0.846353  0.568566
 0.113605  0.143548  0.0720151
 0.978347  0.872861  0.404885
 0.453787  0.070237  0.131692
```

Even though this particular example is contrived for simplicity (we could just use `rand(5, 3` of course)
compare it to the alternative list comprehension syntax:

```julia
[rand() for _ in 1:5, _ in 1:3]
```

```
5×3 Matrix{Float64}:
 0.319974  0.0158858  0.0787176
 0.528733  0.351109   0.644796
 0.629348  0.591767   0.0105735
 0.300175  0.19276    0.983526
 0.741385  0.593077   0.559216
```

## Summary

As you can see, macros can be a gain in syntax clarity, and they offer a powerful way to interact with the user's source code.

Just remember that a reader also needs to understand what's happening.
In our example, `rand()` is not just executed once but many times, which is non-standard behavior for something resembling a function call.
This code-reasoning overhead must always be weighed against the convenience of shorter syntax.

I hope you have learned a thing or two about macros and are encouraged to play around with them yourself.
Usually, good ideas for macros only present themselves after interacting with Julia for a while, so if you are a beginner,
give it time and become proficient with normal functions first.

