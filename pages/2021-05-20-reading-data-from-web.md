@def published = "2021-05-20"
@def title = "Reading data from the web with CSV.jl, DataFrames.jl and Chain.jl"
@def authors = "Julius Krumbiegel"
@def rss = "Reading data from the web with CSV.jl, DataFrames.jl and Chain.jl"
@def rss_pubdate = Date(2021, 05, 20)
@def tags = ["julia"]

# Reading data from the web with CSV.jl, DataFrames.jl and Chain.jl

Recently, I had to read in a dataset from Hillenbrand (1995), published as an annotated csv-like file on a website.
The dataset describes formant frequencies of several vowel utterances from different speakers.
I thought I ended up with a pretty slick implementation showing off some of the tools available in the Julia data science ecosystem.

[Here's the dataset](http://homepages.wmich.edu/~hillenbr/voweldata/bigdata.dat) if you want to look at it.
The challenge is simply that it's a non-standard file format that needs to be massaged into a form ready for CSV reading first.
That means there are also no predefined column names and we don't want to do a lot of work to write all of these out manually, but use the repetitive structure.
My goal is always to write as little unnecessary boilerplate code as possible, without using too much unreadable magic.

Here's the final code, afterwards I'll go through the different statements one by one.

The versions used were CSV v0.8.4, Chain v0.4.5 and DataFrames v1.1.1 with Julia 1.6.

```julia
using Chain, DataFrames, CSV, Downloads

@chain "http://homepages.wmich.edu/~hillenbr/voweldata/bigdata.dat" begin
    Downloads.download(IOBuffer())
    String(take!(_))
    _[findfirst("b01ae", _)[1]:end]
    replace(r" +" => " ")
    replace(r"\s+$"m => "\n")
    CSV.read(IOBuffer(_), DataFrame, header = false,
        missingstring = "0")
    rename(1:30 .=> [
        :filename;
        :duration_msec;
        Symbol.(["f0", "f1", "f2", "f3"], "_steady");
        [Symbol(f, "_", p)
            for p in 10:10:80
            for f in ["f1", "f2", "f3"]]
    ])
    transform(:filename =>
        ByRow(f -> (
            type = f[1],
            number = parse(Int, f[2:3]),
            vowel = f[4:5]
        )) => AsTable)
    transform(:type =>
        ByRow(t -> Dict(
            'm' => "man",
            'w' => "woman",
            'b' => "boy",
            'g' => "girl")[t]) => :type)
    select(1:2, 31:33, 3:30)
    CSV.write("hillenbrand.csv", _)
end
```

Ok, let's look at the parts:

```julia
@chain "http://homepages.wmich.edu/~hillenbr/voweldata/bigdata.dat" begin
```

First, we start a `@chain` from `Chain.jl` with the url we want to download.
In a chain, we can feed the result from one expression into the first argument of the next, unless we specify a different position with the `_` placeholder.

```julia
Downloads.download(IOBuffer())
String(take!(_))
```

We download the content at the url right into an `IOBuffer` object, which avoids creating a separate file.
The IOBuffer is then converted into a string because we have to clean it up a bit.

```julia
_[findfirst("b01ae", _)[1]:end]
replace(r" +" => " ")
replace(r"\s+$"m => "\n")
```

The first line finds the occurence of the first part of the actual data entries, then selects only the part of the string from there on out.
The second line finds all multiple spaces and replaces them with one space, while the third line removes all trailing whitespace before the end of a line.
Both of these things can otherwise throw off CSV.jl when it determines how many columns there are.

```julia
CSV.read(IOBuffer(_), DataFrame, header = false,
    missingstring = "0")
```

Now we convert the string back to an IOBuffer, so that we can use it directly with `CSV.read`.
Using the string itself doesn't work, because CSV.jl would assume it's a file path.
We read into a `DataFrame` and specify that there's no header, because the file has no column names.
We also specify that the string "0" is a missing value, which is the convention of this dataset but which could easily throw off our analyses if we aren't careful.
Using `missing` values forces us to acknowledge them explicitly in our analysis.

```julia
rename(1:30 .=> [
    :filename;
    :duration_msec;
    Symbol.(["f0", "f1", "f2", "f3"], "_steady");
    [Symbol(f, "_", p)
        for p in 10:10:80
        for f in ["f1", "f2", "f3"]]
])
```

Here we rename the columns in a succinct way, the structure is described in the data file.
We broadcast an integer range from 1 to 30, which is the number of columns, with a list of 30 Symbols.
The first two we specify manually, then there's `f0_steady`, `f1_steady`, etc.
Finally, we need to make 24 column names which go like `f1_10`, `f2_10`, `f3_10`, `f1_20`, and so on.
We can easily do this with a nested list comprehension, where we loop over the percentages in the outer loop, and over the formants in the inner loop.

```julia
transform(:filename =>
    ByRow(f -> (
        type = f[1],
        number = parse(Int, f[2:3]),
        vowel = f[4:5]
    )) => AsTable)
```

The data file specifies that some information is encoded in the filename.
We extract this with a function that operates by row, and extracts the three components into fields of a named tuple.
By passing `AsTable` as the sink, these named tuples are automatically expanded into correctly named columns.

```julia
transform(:type =>
    ByRow(t -> Dict(
        'm' => "man",
        'w' => "woman",
        'b' => "boy",
        'g' => "girl")[t]) => :type)
```

The type of speaker is currently encoded as a `Char`, but we can transform this column to a more readable form by looking up the long version of each character in a small dictionary.

```julia
select(1:2, 31:33, 3:30)
```

Our three new columns have been appended at the end, but it would be nicer if the speaker descriptions were more at the front.
So we just use a select statement, where the first two columns come first, then the last three, and then the rest.

```julia
CSV.write("hillenbrand.csv", _)
```

As the last step, we write out the cleaned table into a csv file, and we've already reached the end of this short tutorial.
This is what the end result looks like:

```julia
1668×33 DataFrame
  Row │ filename  duration_msec  type    number  vowel   f0_steady  f1_steady  f2_steady  f3_steady  f1_10  f2_10   f3_10    f1_20  f2_20   f3_20    f1_30  f2_3 ⋯
      │ String    Int64          String  Int64   String  Int64      Int64      Int64?     Int64?     Int64  Int64?  Int64?   Int64  Int64?  Int64?   Int64  Int6 ⋯
──────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
    1 │ b01ae               257  boy          1  ae            238        630       2423       3166    625    2388     3174    651    2413     3115    675    24 ⋯
    2 │ b02ae               359  boy          2  ae            286        829       2495       3218    802    2392     3625    778    2461     3424    793    24
    3 │ b03ae               335  boy          3  ae            214        631       2801       3508    631    2801     3508    602    2760     3453    573    28
    4 │ b04ae               398  boy          4  ae            239        712       2608       3247    729    2604     3239    712    2608     3247    695    25
    5 │ b05ae               267  boy          5  ae            200        748       2589       3042    728    2601     3047    752    2562     3033    767    25 ⋯
    6 │ b07ae               323  boy          7  ae            262        769       2203       3126    769    2203     3126    760    2169     3144    813    22
    7 │ b08ae               316  boy          8  ae            216        870       2281       3077    765    2252     3214    820    2239     3181    864    23
    8 │ b09ae               245  boy          9  ae            220        709       2565       3526    626    2545     3504    709    2565     3526    663    26
    9 │ b10ae               396  boy         10  ae            205        634       2555       3121    635    2560     3230    642    2559     3126    633    25 ⋯
   10 │ b11ae               298  boy         11  ae            209        630       2509       3112    630    2509     3112    627    2513     3098    616    25
   11 │ b12ae               415  boy         12  ae            252        736       2505       3332    729    2544     3261    736    2504     3307    739    25
   12 │ b13ae               281  boy         13  ae            216        634       2535       3260    634    2535     3260    630    2532     3248    623    25
   13 │ b14ae               314  boy         14  ae            198        697       2418       3371    681    2444     3430    657    2471     3376    697    24 ⋯
   14 │ b15ae               382  boy         15  ae            272        607       2620       3350    607    2620     3350    617    2599     3369    628    25
   15 │ b16ae               367  boy         16  ae            187        753       2227       3064    788    2244     3150    750    2233     3042    749    22
   16 │ b17ae               352  boy         17  ae            246        726       2231       2932    726    2231     2932    742    2246     2902    745    22
   17 │ b18ae               307  boy         18  ae            249        741       2444       3043    735    2446     3008    746    2455     3021    748    24 ⋯
   18 │ b19ae               312  boy         19  ae            209        674       2663       3243    684    2665     3268    693    2672     3256    733    26
   19 │ b21ae               352  boy         21  ae            205        769       2234       2910    766    2245     2917    771    2215     2889    771    21
   20 │ b22ae               256  boy         22  ae            229        678       2524       3418    687    2580     3288    678    2501     3424    677    25
```

As always, there are lots of ways of achieving the same thing.
This is just one version that I was satisfied with, and I hope you have learned one or two new techniques that can be useful to you in the future.
