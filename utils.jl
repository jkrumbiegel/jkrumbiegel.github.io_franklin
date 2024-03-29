using Dates
using DataFrames
using Hyperscript

function hfun_bar(vname)
  val = Meta.parse(vname[1])
  return round(sqrt(val), digits=2)
end

function hfun_m1fill(vname)
  var = vname[1]
  return pagevar("index", var)
end

function lx_baz(com, _)
  # keep this first line
  brace_content = Franklin.content(com.braces[1]) # input string
  # do whatever you want here
  return uppercase(brace_content)
end

"""
make a list of blog posts for inclusion on home page
"""
function hfun_blogposts()

    div = m("div")
    ul = m("ul")
    li = m("li")
    a = m("a")
    span = m("span")

    dir = "pages"
    pagelist = readdir(dir)
    filter!(f -> endswith(f, ".md"), pagelist)

    pages = map(pagelist) do page
        open(joinpath(dir, page)) do file
            r = read(file, String)
            
            title = match(r"@def title = \"(.*?)\"", r).captures[1]
            date = Date(match(r"@def published = \"([0-9\-]*)", r).captures[1])
            link = dir * "/" * splitext(page)[1]

            (; title, date, year = year(date), month = month(date), day = day(date), link)
        end
    end |> DataFrame

    sort!(pages, order(:date, rev = true))
    transform!(pages, :year => (x -> -x) => :negative_year)

    yeargroups = map(collect(groupby(pages, :negative_year, sort = true))) do group

        pagedivs = map(eachrow(group)) do page
            li(
                class="post-item",
                a(class = "post-title", href = page.link, page.title),
                span(class = "post-date", monthabbr(page.date), " ", page.day)
            )
        end

        div(
            class="post-year-group",
            div(class = "post-year", first(group.year)),
            ul(class = "post-year-items", pagedivs),
        )
    end

    return repr(div(class = "posts", yeargroups))
end


function hfun_generate_gallery(params)
    entries = locvar(only(params))

    if isnothing(entries)
        @warn "No entries found"
        return ""
    end

    div = m("div")
    img = m("img")
    span = m("span")
    a = m("a")

    mainfolder = "photography"

    mkpath(mainfolder)
    # clear md's and regenerate
    for file in filter(endswith(".md"), readdir(mainfolder, join = true))
        rm(file)
    end

    galleryentries = []

    for (entryname, info) in entries
        assetfolder = joinpath("_assets", "photos", entryname)
        originalsfolder = joinpath(assetfolder, "resized")

        imagefiles = filter(endswith(".jpg"), readdir(originalsfolder))

        originalsfolder_web = joinpath("/assets", "photos", entryname, "resized")
        titlephoto = get(info, :titlephoto, imagefiles[1])
        titlephotopath = joinpath(originalsfolder_web, titlephoto)

        d = a(
            href = joinpath("/", mainfolder, entryname),
            div(
                class = "photogrid-entry",
                span(info.title),
                img(src = titlephotopath, class = "gridimage")
            )
        )
        push!(galleryentries, d)

        open(joinpath(mainfolder, "$entryname.md"), "w") do f
            println(f, "@@photopage")
            println(f, "@def title = \"$(info.title)\"")
            println(f, "# $(info.title)")
            println(f, "~~~")
            println(f, photogallery_html(imagefiles, originalsfolder_web))
            println(f, "~~~")
            println(f, "@@")
        end
    end

    div(galleryentries, class = "photogrid") |> repr
end

function photogallery_html(imagefiles, originalsfolder_web)
    div = m("div")
    img = m("img")

    div(
        [img(src = joinpath(originalsfolder_web, im)) for im in imagefiles],
        class = "photocolumn"
    )
end