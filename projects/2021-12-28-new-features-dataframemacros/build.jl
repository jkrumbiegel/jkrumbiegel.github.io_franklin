using Literate
cd(@__DIR__)
file = "2021-12-28-new-features-dataframemacros.jl"
md = splitext(file)[1] * ".md"
Literate.markdown(
    file,
    execute = true,
    credit = false,
    flavor = Literate.FranklinFlavor()
)
mv(md, joinpath("..", "..", "pages", md), force = true)