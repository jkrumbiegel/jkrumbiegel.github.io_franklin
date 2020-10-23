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
    list = readdir("pages")
    filter!(f -> endswith(f, ".md"), list)
    filter!(f -> !occursin("draft", f), list)
    sort!(list, rev=true)
    io = IOBuffer()
    @info " ... updating post list"
    write(io, "
")
    write(io, "<div class=\"postlist\">\n")
    write(io, "    <div class=postgrid>\n")
    for (k, i) in enumerate(list)
        title = open(joinpath("pages", i)) do f
            r = read(f, String)
            m = match(r"@def title = \"(.*?)\"", r)
            return string(first(m.captures))
        end
        @info " .... processing page $title"
        pagename = first(splitext(i))
        postdate = pagename[1:10]
        k = "     <p><a href=\"/pages/$(pagename)/\">$(title)</a> $(postdate) </p>"
        write(io, """ $k\n""")
    end
    write(io, "    </div>\n")
    write(io, "</div>\n")
    write(io, "
")
    return String(take!(io))
end