using ImageTransformations
using FileIO

max_sidelength = 1800
jpg_quality = 50

topfolder = "../../_assets/photos"
@assert isdir(topfolder)
subfolders = filter(x -> isdir(joinpath(topfolder, x)), readdir(topfolder))

new_size(sz, maxlen) = round.(Int, sz ./ maximum(sz) .* min(maximum(sz), maxlen))

for subfolder in subfolders
    originalfolder = joinpath(topfolder, subfolder, "originals")
    newfolder = joinpath(topfolder, subfolder, "resized")
    if isdir(newfolder)
        rm(newfolder, recursive = true)
        # @warn "$newfolder already exists, skipping"
        # continue
    else
        mkpath(newfolder)
    end

    for filename in readdir(originalfolder)
        println(filename)
        !(endswith(filename, ".jpg")) && continue
        image = load(joinpath(originalfolder, filename))
        sz = size(image)
        newsize = new_size(sz, max_sidelength)
        resized = imresize(image, newsize)
        newpath = joinpath(newfolder, filename)
        save(newpath, resized, quality = jpg_quality)
    end
end
