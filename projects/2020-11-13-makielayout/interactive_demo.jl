using AbstractPlotting
using AbstractPlotting.MakieLayout
using GLMakie
GLMakie.activate!()
set_window_config!(float = true, vsync = false)

##



function panel_1(scene, gridpos)

    layout = gridpos[] = GridLayout()

    subgl = layout[1, 1] = GridLayout()
    ax1 = subgl[1, 1] = LAxis(scene)
    deregister_interaction!(ax1, :rectanglezoom)

    but = LButton(scene, label = "Random Axis")
    but2 = LButton(scene, label = "Random Colorbar")

    layout[2, 1] = hbox!(but, but2, tellwidth = false)

    cmaps = [:viridis, :heat, :Blues, :jet, :rainbow]
    heatmap!(ax1, [sin(x) * cos(y) for x in LinRange(0, 8pi, 100), y in LinRange(0, 8pi, 100)], colormap = rand(cmaps))
    tightlimits!(ax1)

    on(but.clicks) do c
        nc, nr = ncols(subgl), nrows(subgl)
        ax = if nc == nr
            subgl[1:end, end+1] = LAxis(scene)
        else
            subgl[end+1, 1:end] = LAxis(scene)
        end
        deregister_interaction!(ax, :rectanglezoom)
        heatmap!(ax, [sin(x) * cos(y) for x in LinRange(0, 8pi, 100), y in LinRange(0, 8pi, 100)], colormap = rand(cmaps))
        tightlimits!(ax)
    end

    on(but2.clicks) do c
        nc, nr = ncols(subgl), nrows(subgl)
        cb = if nc == nr
            subgl[1:end, end+1] = LColorbar(scene, width = 30, colorma = rand(cmaps))
        else
            subgl[end+1, 1:end] = LColorbar(scene, height = 30, vertical = false, colormap = rand(cmaps),
                ticklabelalign = (:center, :bottom))
        end
    end

    layout

end

function panel_2(scene, gridpos)

    layout = gridpos[] = GridLayout()

    ax = layout[1, 1] = LAxis(scene, title = "Simple Dampened Sine Wave", xlabel = "Time", ylabel = "Amplitude")
    deregister_interaction!(ax, :rectanglezoom)

    tsl1 = labelslider!(scene, "Frequency", 1:0.01:10, valuekw = (width = 50,))
    tsl2 = labelslider!(scene, "Gain", 0.5:0.001:2, valuekw = (width = 50,))
    tsl3 = labelslider!(scene, "Damping", 0.0:0.001:1, valuekw = (width = 50,))
    set_close_to!(tsl2.slider, 1.0)

    layout[2, 1] = tsl1.layout
    layout[3, 1] = tsl2.layout
    layout[4, 1] = tsl3.layout

    lines!(ax, 0..8pi, @lift((sin.((0:0.01:8pi) .* $(tsl1.slider.value)) .* $(tsl2.slider.value)) ./ exp.((0:0.01:8pi) .* $(tsl3.slider.value))))

    layout

end

function functionplot(ax, f; kwargs...)
    points = lift(ax.limits) do lims
        xs = LinRange(minimum(lims)[1], maximum(lims)[1], 500)
        ys = f.(xs)
        Point2f0.(xs, ys)
    end
    lines!(ax, points; xautolimits = false, yautolimits = false, kwargs...)
end

function pushplot!(leg::LLegend, content, label)

    groups = leg.entrygroups[]
    title, legendentries = groups[1]

    entries = push!(legendentries, LegendEntry(label, content))
    leg.entrygroups[] = [(title, entries)]
    nothing
end

function panel_3(scene, gridpos)
    layout = gridpos[] = GridLayout()

    ax = layout[1, 1] = LAxis(scene, title = "Dynamic function plotting", xlabel = "x", ylabel = "f(x)")
    limits!(ax, -10, 10, -10, 10)

    tb = LTextbox(scene, width = 300, placeholder = "enter function...", reset_on_defocus = false)
    layout[2, 1] = hbox!(LText(scene, "f(x) ="), tb, tellwidth = false)

    
    iscomplete(x::Expr) = x.head != :incomplete
    iscomplete(x) = true
    iscomplete(x::Nothing) = false

    tb.validator[] = function(str)
        try
            iscomplete(Meta.parse(str))
        catch
            false
        end
    end

    leg = nothing

    on(tb.stored_string) do str
        if leg === nothing
            leg = layout[1, 2] = LLegend(scene, [], String[], "Functions")
        end
        try
            exp = Meta.parse(str)
            f = @eval(x -> $exp)
            g(x) = Base.invokelatest(f, x)
            p = functionplot(ax, g; color = rand(RGBf0), linewidth = 3)

            pushplot!(leg, p, str)
        catch
        end
    end

    layout
end

function Base.delete!(layout::GridLayout)
    contentvector = copy(layout.content)

    for c in contentvector
        delete!(c.content)
        MakieLayout.GridLayoutBase.remove_from_gridlayout!(c)
    end
end


let
    set_theme!(font = "Avenir Light", fontsize = 30)

    scene, layout = layoutscene()

    layout[1, 1:2] = LText(scene, "GUIs with MakieLayout", textsize = 40)

    lmenu = layout[2, 1] = LMenu(scene,
        options = zip(["Grid Layout", "Sine Wave", "Dynamic Functions"], [panel_1, panel_2, panel_3]),
        textsize = 30,
        width = 300,
        tellheight = false)

    gp = layout[2, 2]

    on(lmenu.selection) do s
        if s isa Function
            l = contents(layout[2, 2])
            delete!.(l)
            s(scene, gp)
        end
    end

    scene
end


