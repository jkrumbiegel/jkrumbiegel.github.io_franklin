@def published = "2021-12-28 00:00:00 +0000"
@def title = "Multi-columns, shortcut strings and subset transformations in DataFrameMacros.jl v0.2"
@def authors = "Julius Krumbiegel"
@def rss = "Multi-columns, shortcut strings and subset transformations in DataFrameMacros.jl v0.2"
@def rss_pubdate = Date(2021, 12, 28)
@def rss_author = "Julius Krumbiegel"
@def tags = ["julia"]

# Multi-columns, shortcut strings and subset transformations in DataFrameMacros.jl v0.2

[DataFrameMacros.jl](https://github.com/jkrumbiegel/DataFrameMacros.jl) is a Julia package that makes it easier to manipulate DataFrames, by rewriting code into source-function-sink expressions that conform to DataFrames.jl's more verbose mini-language.
In version v0.2 (and v0.2.1) I have added a couple new features that are powerful, but not immediately obvious.
This post takes a closer look at the new functionality.

The new features are multi-column specifiers, shortcut strings for renaming and subset transformations.

## Multi-column specifiers

So far, DataFrameMacros.jl only supported statements with single-column specifiers.
For example, `@select(df, :x + 1)` or `@combine(df, $column_variable * $2)`.
The expressions `:x`, `$column_variable` and `$2` all refer to one column each.
The underlying source-function-sink expression that DataFrameMacros.jl created was therefore always of the form `source => function => sink`.
For many tasks this is perfectly sufficient, but other times one wants to execute the same function over a set of similar or related columns.

DataFrames.jl has a neat way to run the same function on a set of columns.
This is done by using the `.=>` operator, to broadcast over a set or sets of columns and create an array of `source => function => sink` expressions.
For example, you could compute the sum for each column in a DataFrame with `transform(df, names(df, All()) .=> sum)`, or in the recent v1.3 release even with `transform(df, All() .=> sum)`.

Now, the trick that DataFrameMacros.jl v0.2.1 uses is to change the underlying representation from `source => function => sink` to `source(s) .=> function(s) .=> sink(s)`.
This doesn't break the existing functionality, because scalars in Julia broadcast just fine, so it's no problem to say something like `combine(df, :x .=> sum .=> "y")` - even though broadcasting doesn't add anything if only scalars participate.

Where it gets interesting is when collections of columns are used.
With the change to `source(s) .=> function(s) .=> sink(s)` you are now free to use column expressions that refer to multiple columns.
The only restriction is that the shapes of `source(s)`, `function(s)` and `sink(s)` have to be compatible for broadcasting.

There are multiple ways in which you can reference multiple columns at once, and they are closely related to what `x` can be in the function `names(df, x)`.
For example, `All()`, `Between(x, y)` and `Not(args...)` are now recognized directly as multi-column specifiers by DataFrameMacros, without having to mark them with the usual `$` sign.
Then you can use any `Type` `T` marked by `$`, which selects all columns whose elements are subtypes of `T`, for example `$Real` or `$String`.
You can use a regex that selects all columns with matching names, for example `$(r"a")` for any column with the letter `a`.
Of course it's also possible to just pass an array of column names, for example `$["a", "b"]`.

Here are a few practical examples:

````julia
using DataFrameMacros
using DataFrames

df = DataFrame(
    name = ["alice", "bob", "charlie"],
    age = [20, 31, 42],
    country = ["andorra", "brazil", "croatia"],
    salary = [9999, 6666, 3333],
)
````

````
3×4 DataFrame
 Row │ name     age    country  salary
     │ String   Int64  String   Int64
─────┼─────────────────────────────────
   1 │ alice       20  andorra    9999
   2 │ bob         31  brazil     6666
   3 │ charlie     42  croatia    3333
````

We can transform both `String` columns at once and both `Int` columns at once, by using the `Type` multi-column specifier.

````julia
x = @select df begin
    uppercasefirst($String)
    Float64($Int)
end
print(x)
````

````
3×4 DataFrame
 Row │ name_uppercasefirst  country_uppercasefirst  age_Float64  salary_Float64
     │ String               String                  Float64      Float64
─────┼──────────────────────────────────────────────────────────────────────────
   1 │ Alice                Andorra                        20.0          9999.0
   2 │ Bob                  Brazil                         31.0          6666.0
   3 │ Charlie              Croatia                        42.0          3333.0
````

We can try out the `All()` specifier by reversing the element order of each column.
We need the `@c` flag so `reverse` acts on each column vector and not each column element.
This works the same way with the `Between` and `Not` selectors.

````julia
@select df @c reverse(All())
````

````
3×4 DataFrame
 Row │ name_reverse  age_reverse  country_reverse  salary_reverse
     │ String        Int64        String           Int64
─────┼────────────────────────────────────────────────────────────
   1 │ charlie                42  croatia                    3333
   2 │ bob                    31  brazil                     6666
   3 │ alice                  20  andorra                    9999
````

We can combine multi-column specifiers with single-column specifiers, they can always broadcast together because scalars work together with any shape.
For example, let's say we have a column with tax rates and four columns with quarterly gains and we want to compute the quarterly taxes.

````julia
df = DataFrame(
    year = [2019, 2020, 2021],
    tax_rate = [0.19, 0.20, 0.21],
    income_q1 = [2000, 3000, 4000],
    income_q2 = [2100, 3100, 4100],
    income_q3 = [2200, 3200, 4200],
    income_q4 = [2300, 3300, 4300],
)
````

````
3×6 DataFrame
 Row │ year   tax_rate  income_q1  income_q2  income_q3  income_q4
     │ Int64  Float64   Int64      Int64      Int64      Int64
─────┼─────────────────────────────────────────────────────────────
   1 │  2019      0.19       2000       2100       2200       2300
   2 │  2020      0.2        3000       3100       3200       3300
   3 │  2021      0.21       4000       4100       4200       4300
````

Then we can simply multiply the tax rate with the four income columns at once, which we select with the `Between` selector.

````julia
@select(df, :tax_rate * Between(3, 6))
````

````
3×4 DataFrame
 Row │ tax_rate_income_q1_*  tax_rate_income_q2_*  tax_rate_income_q3_*  tax_rate_income_q4_*
     │ Float64               Float64               Float64               Float64
─────┼────────────────────────────────────────────────────────────────────────────────────────
   1 │                380.0                 399.0                 418.0                 437.0
   2 │                600.0                 620.0                 640.0                 660.0
   3 │                840.0                 861.0                 882.0                 903.0
````

Another option to select the columns would be to use a regex.
We have to mark it with `$` so that DataFrameMacros knows to treat it as a column specifier.

````julia
@select(df, :tax_rate * $(r"income"))
````

````
3×4 DataFrame
 Row │ tax_rate_income_q1_*  tax_rate_income_q2_*  tax_rate_income_q3_*  tax_rate_income_q4_*
     │ Float64               Float64               Float64               Float64
─────┼────────────────────────────────────────────────────────────────────────────────────────
   1 │                380.0                 399.0                 418.0                 437.0
   2 │                600.0                 620.0                 640.0                 660.0
   3 │                840.0                 861.0                 882.0                 903.0
````

Now one issue is that the resulting column names are very ugly.
We could specify the new names directly as a vector.
Remember that the expression is `source(s) .=> function(s) .=> sink(s)` so we can also broadcast a vector of sinks.
The string `"taxes_q1"` will be the sink associated with the first element from the regex selector, and so on.

````julia
@select(df,
    ["taxes_q1", "taxes_q2", "taxes_q3", "taxes_q4"] = :tax_rate * $(r"income"))
````

````
3×4 DataFrame
 Row │ taxes_q1  taxes_q2  taxes_q3  taxes_q4
     │ Float64   Float64   Float64   Float64
─────┼────────────────────────────────────────
   1 │    380.0     399.0     418.0     437.0
   2 │    600.0     620.0     640.0     660.0
   3 │    840.0     861.0     882.0     903.0
````

But writing out strings like that is error prone, especially if the order of columns can change.
So it would be better to transform the original column names.
DataFrames allows to use anonymous functions for this, the input for the function is a vector with all column names used in the expression.
We can split off the `"q1"` part from the second column in each expression (the income column) and prefix with `"taxes_"`:

````julia
@select(df, (names -> "taxes_" * split(names[2], "_")[2]) = :tax_rate * $(r"income"))
````

````
3×4 DataFrame
 Row │ taxes_q1  taxes_q2  taxes_q3  taxes_q4
     │ Float64   Float64   Float64   Float64
─────┼────────────────────────────────────────
   1 │    380.0     399.0     418.0     437.0
   2 │    600.0     620.0     640.0     660.0
   3 │    840.0     861.0     882.0     903.0
````

### Broadcasting with more than one dimension

You are not technically limited to broadcasting one vector of columns with scalar columns, you can even evaluate two- or higher-dimensional grids of column combinations if you like.
For example, if you had two different tax rates and three income categories, you could compute all six tax columns with one expression.
Here we extract the income columns first so we can make them into a row-vector with `permutedims`, which will form a 2D grid when broadcasted together with the column vector with the two tax columns.

````julia
df = DataFrame(
    year = [2019, 2020, 2021],
    tax_a = [0.19, 0.20, 0.21],
    tax_b = [0.22, 0.23, 0.24],
    income_a = [2000, 3000, 4000],
    income_b = [2100, 3100, 4100],
    income_c = [2200, 3200, 4200],
)

income_cols = permutedims(names(df, r"income"))

@select(df, $(r"tax") * $income_cols)
````

````
3×6 DataFrame
 Row │ tax_a_income_a_*  tax_b_income_a_*  tax_a_income_b_*  tax_b_income_b_*  tax_a_income_c_*  tax_b_income_c_*
     │ Float64           Float64           Float64           Float64           Float64           Float64
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │            380.0             440.0             399.0             462.0             418.0             484.0
   2 │            600.0             690.0             620.0             713.0             640.0             736.0
   3 │            840.0             960.0             861.0             984.0             882.0            1008.0
````

The column names are again not ideal, which brings us to another new feature.

## Shortcut strings for renaming

Often, we want to give new columns names that are just simple combinations of column names used to compute them.
In the last example, a better name than `tax_a_income_a_*` could be `tax_a_on_income_b`.

If DataFrameMacros encounters a string literal as the sink which contains `"{}"`, `"{1}"` or `"{2}"` and up, it translates this into a renaming function that pastes the input column names at the respective locations.
Here's the last example again with such a shortcut string:

````julia
@select(df, "{1}_on_{2}" = $(r"tax") * $income_cols)
````

````
3×6 DataFrame
 Row │ tax_a_on_income_a  tax_b_on_income_a  tax_a_on_income_b  tax_b_on_income_b  tax_a_on_income_c  tax_b_on_income_c
     │ Float64            Float64            Float64            Float64            Float64            Float64
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │             380.0              440.0              399.0              462.0              418.0              484.0
   2 │             600.0              690.0              620.0              713.0              640.0              736.0
   3 │             840.0              960.0              861.0              984.0              882.0             1008.0
````

## Subset transformations

The third new feature goes hand in hand with a new addition in DataFrames v1.3.
Now you can call `transform!` or `select!` on the view returned by `subset(df, some_subset_expression, view = true)`, and this will mutate the underlying DataFrame only in the selected rows.
If new columns are added, all rows outside the subset are filled with `missing` values.

In base DataFrames, you need to first create a subset view, then mutate it, then continue on with the original DataFrame.
Here's the DataFrame we start with

````julia
df = DataFrame(x = 1:4, y = 5:8)
````

````
4×2 DataFrame
 Row │ x      y
     │ Int64  Int64
─────┼──────────────
   1 │     1      5
   2 │     2      6
   3 │     3      7
   4 │     4      8
````

Now we subset some rows and increment the y values by 10 there.
We also create new z values:

````julia
subset_view = subset(df, :x => ByRow(>=(3)), view = true)
transform!(
    subset_view,
    :y => ByRow(x -> x + 10) => :y,
    :x => (x -> x * 3) => :z
)
df
````

````
4×3 DataFrame
 Row │ x      y      z
     │ Int64  Int64  Int64?
─────┼───────────────────────
   1 │     1      5  missing
   2 │     2      6  missing
   3 │     3     17        9
   4 │     4     18       12
````

In DataFrameMacros v0.2, you can now use a more convenient syntax that plays well with Chain.jl or other piping mechanisms, where you only want to use functions that return the DataFrame you work with, not a subset view.
You can simply pass a `@subset` expression to `@transform!` or `@select!` after the DataFrame argument.
This `@subset` expression doesn't take its own DataFrame argument as usual, that's implied to be the DataFrame that is being transformed.
The returned object after mutating the selected rows is the original DataFrame.
You can see how much more concise the same operation becomes:

````julia
df = DataFrame(x = 1:4, y = 5:8)
@transform!(df, @subset(:x >= 3), :y = :y + 10, :z = 3 * :x)
````

````
4×3 DataFrame
 Row │ x      y      z
     │ Int64  Int64  Int64?
─────┼───────────────────────
   1 │     1      5  missing
   2 │     2      6  missing
   3 │     3     17        9
   4 │     4     18       12
````

## Summary

That concludes the overview of the three new features, multi-column specifiers, shortcut strings for renaming and subset transformations.
Especially multi-column specifiers with their implicit broadcasting might need a moment to wrap your head around, but I think you'll find them very convenient.
I hope you enjoy using the new release!

