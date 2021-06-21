outputfolder = "output"
assetfolder = "../../_assets"
assetfolder_html = "/assets"
pagefolder = "../../pages"

# you have to be cd'ed into the correct folder
name = splitpath(pwd())[end]
files = readdir("output", join = true)

md = only(filter(endswith(".md"), files))

s = String(read(md))

other_files = filter(!endswith(".md"), files)

assetdir = joinpath(assetfolder, name)
assetdir_html = joinpath(assetfolder_html, name)

if isdir(assetdir)
    rm(assetdir, recursive = true)
end

mkpath(assetdir)


for f in other_files
    bf = basename(f)
    s = replace(s, bf => joinpath(assetdir_html, bf))
    cp(f, joinpath(assetdir, bf))
end

open(joinpath(pagefolder, name * ".md"), "w") do file
    print(file, s)
end