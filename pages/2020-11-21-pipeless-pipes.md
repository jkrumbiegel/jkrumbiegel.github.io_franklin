@def published = "2020-11-21"
@def title = "PipelessPipes.jl - Even More Convenient Piping"
@def authors = "Julius Krumbiegel"
@def rss = "PipelessPipes.jl - Even More Convenient Piping"
@def rss_pubdate = Date(2020, 11, 21)
@def tags = ["julia"]


# PipelessPipes.jl - Even More Convenient Piping

![magritte](/assets/2020-11-21-pipeless-pipes/magritte.png)

[PipelessPipes.jl](https://github.com/jkrumbiegel/PipelessPipes.jl) is a new Julia macro package for piping which I recently wrote because I wasn't quite satisfied with the available options.
In short, it allows to omit pipe operators, it implicitly assumes first argument piping if not otherwise stated explicitly, it allows for more helpful error highlighting and enables you to interject arbitrary statements into the pipeline for debugging.

Read on if you don't yet know how piping works or are interested in the motivation and reasoning behind writing a macro package like this.

## What Is Piping?

In case you don't know it yet, piping is a way of applying a number of functions to an input in sequence.
The output of the first function is fed to the second one, the output of the second is fed to the third one, and so on.
This way of writing is often found in data science applications, because it fits the workflow of passing one dataframe through multiple transformations very well.

Here's one example without piping. Let's start with some arbitrary dataframe, although this article is only about syntax:

```julia
using DataFrames

df = DataFrame(
    :id => 1:100,
    :color => rand(["red", "green", "blue"], 100),
    :shape => rand(["round", "square"], 100),
    :weight => 5 .* randn(100) .+ 100,
)
```

Now lets calculate something with this dataframe:

```julia
combine(groupby(filter(row -> row.weight < 100, select(df, Not(:id)), [:color, :shape]), :weight => sum => :total_weight)
```

That's pretty hard to read, here's the same thing with indentation:

```julia
combine(
    groupby(
        filter(row -> row.weight < 100,
            select(df, Not(:id))
        ),
        [:color, :shape]),
    :weight => sum => :total_weight
)
```

That's better, but still not very easy to read because of the nesting levels.
How many transformation steps are there, and what do they do?
There's a `select`, then a `filter`, then a `groupby` and then a `combine` transformation.
It takes some time to untangle that.

We can clean up the order if we use temporary variables:

```julia
selected = select(df, Not(:id))
filtered = filter(row -> row.weight < 100, selected)
grouped = groupby(filtered, [:color, :shape])
combined = combine(grouped, :weight => sum => :total_weight)
```

Now the order is good, but we really don't want to write a temp variable for each line. What can we do?

## Original Pipes

Here's another version using Julia's `|>` pipe operator, where the expression `x |> f` ist the same as `f(x)`, just written sequentially (like a _pipeline_).


```julia
df |>
    x -> select(x, Not(:id)) |>
    x -> filter(row -> row.weight < 100, x) |>
    x -> groupby(x, [:color, :shape]) |>
    x -> combine(x, :weight => sum => :total_weight)
```

Two things stick out: There are obviously four steps to this pipeline, and they are easy to read in order, which is nice.
We can read `select`, `filter`, `groupby` and `combine` from top to bottom.

But we also have a lot of anonymous functions here with all those `x ->` statements.

We need to write all these anonymous functions because the `|>` operator can only do `f(x)`, that means it can take a function and exactly one argument and apply the function to it.
It doesn't allow for giving two arguments, which we need for each of the transformations to specify what we're actually doing with our dataframe.
Just `groupby(df)` doesn't do anything.
That's why we convert each of our two-argument function calls into a mini-function that takes only one argument.
We're fixing the second argument within each anonymous functions, which is a form of [Currying](https://en.wikipedia.org/wiki/Currying).

Why would you do this, you ask, and the answer is, _you wouldn't_.
It's a hassle to write and read.
The standard Julia `|>` operator works well with functions that only take one argument anyway, like `mean` or `sum`, or maybe `display`, but it creates syntactical overhead if we want anything more complex.

Still, the sequential style is much nicer for our purpose than the nested style, so how can we improve on this?
We can't actually get much better with Julia's normal syntax, so from here on out, we need to go into macro territory.

## Pipe.jl

If we think about ways we can simplify the pipe example with macros, the first idea would be to eliminate the `x -> ...` overhead that repeats every line.
That's what Pipe.jl's `@pipe` macro does.
It replaces `_` in every right-hand expression with the result of the left-hand expression.
We can use it to rewrite our example like this:

```julia
using Pipe

@pipe df |>
    select(_, Not(:id)) |>
    filter(row -> row.weight < 100, _) |>
    groupby(_, [:color, :shape]) |>
    combine(_, :weight => sum => :total_weight)
```

This is much nicer to read, all the anonymous functions are gone.
There are some things that could be better, though.

One is that the whole pipe errors as a whole if it errors, which doesn't help when debugging.
Look at this variation of our example:

```julia
@pipe df |>
    select(_, Not(:id)) |>
    filter(row -> row.weight < 100, _) |>
    groupby(_, (:color, :shape)) |>
    combine(_, :weight => sum => :total_weight)
```

If we run it, the error message tells us this, which is not immediately obvious:

```julia
ERROR: LoadError: MethodError: no method matching getindex(::DataFrames.Index, ::Tuple{Symbol, Symbol})
```

And this is what VSCode marks red, just the entry point of the pipe:

![pipe.jl](/assets/2020-11-21-pipeless-pipes/pipe.png)

The actual mistake is the tuple in the `groupby` line.
In more complex pipelines, it can take a while until you found your culprit.

One other problem is that it's not so easy to comment out parts of the pipeline from the end, because there can be no dangling `|>`.
That means if we temporarily want to comment out the `combine` line, we also have to remove the previous `|>`, which is annoying.
Actually, typing `|>` at all is annoying, I find.

Additionally, we can see that three out of four functions take the df as the first argument.
Actually, most functions, especially those around DataFrames.jl, do take the "main" argument as the first one, although it's not all functions, as you can see with `filter`.

There is some optimization potential here to make everything as convenient and legible as possible, which led me to create `PipelessPipes.jl`.

## PipelessPipes.jl

PipelessPipes does away with the pipe operator, because we don't really need it if we mark our whole block as one big pipe anyway.
This saves typing and solves the dangling operator issue when commenting out lines from the end.

We just use the `@_` macro to treat every expression in the following block (usually one expression is what's happening within one line) as one step of our pipe.

Our example therefore turns into this:

```julia
using PipelessPipes

@_ df begin
    select(_, Not(:id))
    filter(row -> row.weight < 100, _)
    groupby(_, (:color, :shape))
    combine(_, :weight => sum => :total_weight)
end
```

Now, there's one more convenience optimization left on the table, and that's all the underscores in first argument position.
It would be nice to be able to omit those as well, because most functions will take the thing to pipe as the first argument.

So we introduce a rule that any expression without an underscore gets an implicit underscore in the first argument position.
Then our example turns into this:

```julia
@_ df begin
    select(Not(:id))
    filter(row -> row.weight < 100, _)
    groupby((:color, :shape))
    combine(:weight => sum => :total_weight)
end
```

Now there is basically no redundant information in the pipe anymore, everything is encoded in the `@_` macro and the rules attached to it.

_(As a side note, there is the `@>` macro from Lazy.jl which does a similar transformation, but it only works with first arguments, while other similar macros to Pipe.jl don't allow you to omit the first argument like `@_` does.)_

As a bonus, the error message example turns into this, clearly showing that the `groupby` line is wrong:

![pipeless](/assets/2020-11-21-pipeless-pipes/pipeless.png)

### Interjecting Debugging Statements

Often, I have a pipeline which doesn't work _quite_ right, but I don't know immediately where it goes wrong.
In those cases, I often want to print out some information within the pipeline, just to check if my assumptions hold.
Most piping packages I know do not consider this possibility and have no way to execute a function that doesn't affect the following pipeline steps.

PipelessPipes.jl has a special marker macro `@!` which you can use to mark expressions that should just be executed without forwarding their result, instead continuing with the previous result.

For example, if we wanted to check for some reason how much data we have left after filtering, we could do this:

```julia
@_ df begin
    select(Not(:id))
    filter(row -> row.weight < 100, _)
    @! println("There are $(nrow(_)) rows after filtering.")
    groupby([:color, :shape])
    combine(:weight => sum => :total_weight)
end
```

As you can see, the `@!` clearly marks that there's something different going on in the third line, and we can still use the `_` to easily refer to the current result.
Note that in these special lines, there is no implicit insertion of an underscore into an expression without one, because it would be inconvenient not to be able to use a simple `println("step 5 done")`, for example.

## Conclusion

I hope you have seen how macros can allow you to bend Julia's syntax to your will and impose your own rules in order to maximize clarity and remove redundancy.
If you want more information about the macro or look at the source code (it's quite short), check out the [Github repository](https://github.com/jkrumbiegel/PipelessPipes.jl).