cd(@__DIR__)
using Pkg
Pkg.activate(".")


using CairoMakie
using CairoMakie.AbstractPlotting.MakieLayout
using CairoMakie.AbstractPlotting.ColorSchemes
CairoMakie.activate!(type = "png")



function example_1()

    scene, layout = layoutscene(resolution = (1200, 1000), font = "Avenir Light")

    topgl = layout[1, 1:3] = GridLayout()
    leftgl = topgl[1, 1] = GridLayout()

    ax_l = leftgl[1, 1] = LAxis(scene, title = "Pyramidal Cells")
    ax_r = leftgl[1, 2] = LAxis(scene, title = "Layer IV Neurons")

    leftgl[1, 1:2, Bottom()] = LText(scene, "Sagittal", padding = (0, 0, 0, 5))
    leftgl[1, 1, Left()] = LText(scene, "Coronal", rotation = pi/2, padding = (0, 5, 0, 0))

    hidexdecorations!.([ax_l, ax_r])
    hideydecorations!.([ax_l, ax_r])

    xs = LinRange(0.5, 6, 50)
    ys = LinRange(0.5, 6, 50)
    data1 = [sin(x^1.5) * cos(y^0.5) for x in xs, y in ys] .+ 0.1 .* randn.()
    data2 = [sin(x^0.8) * cos(y^1.5) for x in xs, y in ys] .+ 0.1 .* randn.()
    hm = contourf!(ax_l, xs, ys, data1,
        levels = 6)
    contour!(ax_l, xs, ys, data1, color = :black)

    hm2 = contourf!(ax_r, xs, ys, data2,
        levels = 6)
    contour!(ax_r, xs, ys, data2, color = :black)

    cbar = leftgl[2, :] = LColorbar(scene, vertical = false, height = 20, flipaxisposition = false, ticklabelalign = (:center, :top), label = "Spike Rate")


    ax2 = topgl[1, 2] = LAxis(scene, title = "Particle Simulation", xlabel = "Velocity [m/s]", ylabel = "Acceleration [m/s²]")
    scat = scatter!(ax2, randn(100, 2) * [1 2; 2 1], color = rand(1:5, 100), colormap = :Spectral, colorrange = (1, 10))
    scatter!(ax2, randn(100, 2) * [1 -2; -3 1], color = rand(6:10, 100), colormap = :Spectral, colorrange = (1, 10))

    cb = topgl[1, 3] = LColorbar(scene, scat, width = 20, label = "Energy [j/mol]", alignmode = Outside())

    layout[2, :] = LRect(scene, color = :gray94)
    layout[2, :] = LText(scene, "Group Measurements", padding = (5, 5, 5, 5))

    colors = ColorSchemes.Set1_4[1:3]

    groupslayout = layout[3, :] = GridLayout()

    small_axes = LAxis[]
    for group in 1:3
        gl = groupslayout[1, group] = GridLayout(default_rowgap = 10, default_colgap = 10)

        axs = gl[] = [LAxis(scene,
            xticklabelalign = (:right, :center),
            xticklabelrotation = pi/4,
            xticks = LinearTicks(3))
            for _ in 1:3, _ in 1:3]

        append!(small_axes, axs)

        for i in 1:3, j in 1:3
            for n in 1:3
                lines!(axs[i, j], LinRange(0, 1, 100), x -> i * exp(0.5group * x) + j + n + 0.2group * randn(), color = colors[n])
            end
        end


        hidexdecorations!.(axs[1:end-1, :], grid = false)
        hideydecorations!.(axs[:, 2:end], grid = false)

        gl[1, :, Top()] = LText(scene, "Group $group", padding = (0, 0, 5, 0))
    end

    linkaxes!(small_axes...)

    groupslayout[1, 4] = LLegend(scene,
        [LineElement(color = c, linewidth = 1, linestyle = nothing) for c in colors],
        ["A", "B", "C"],
        "Condition"
    )

    layout[0, :] = LText(scene, "Hygroscopic Transmission In Sublaminar Membranes", textsize = 24, font = "Avenir Demi")

    scene

end

scene = example_1()

mkpath("./img")
save("img/example_1.svg", scene)