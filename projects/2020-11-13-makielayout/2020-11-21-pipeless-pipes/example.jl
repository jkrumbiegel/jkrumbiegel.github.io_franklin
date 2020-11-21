cd(@__DIR__)
using Pkg
Pkg.activate(".")


using DataFrames
using Pipe
using Chain


df = DataFrame(
    :id => 1:100,
    :color => rand(["red", "green", "blue"], 100),
    :shape => rand(["round", "square"], 100),
    :weight => 5 .* randn(100) .+ 100,
)


@pipe df |>
    select(_, Not(:id)) |>
    filter(row -> row.weight < 100, _) |>
    groupby(_, (:color, :shape)) |>
    combine(_, :weight => sum => :total_weight)

@chain df begin
    select(Not(:id))
    filter(row -> row.weight < 100, _)
    groupby((:color, :shape))
    combine(:weight => sum => :total_weight)
end

df |>
    x -> select(x, Not(:id)) |>
    x -> filter(row -> row.weight < 100, x) |>
    x -> groupby(x, [:color, :shape]) |>
    x -> combine(x, :weight => sum => :total_weight)