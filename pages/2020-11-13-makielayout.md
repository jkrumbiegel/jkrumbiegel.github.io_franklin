@def published = "2020-11-15"
@def title = "Try MakieLayout - Perfect Layouts For Interactive Scientific Graphics in Julia"
@def authors = "Julius Krumbiegel"
@def rss = "Try MakieLayout - Perfect Layouts For Interactive Scientific Graphics in Julia"
@def rss_pubdate = Date(2020, 11, 15)
@def tags = ["julia"]

# Try MakieLayout - Perfect Layouts For Interactive Scientific Graphics in Julia

## Making Beautiful Plots Is Hard

Researchers often need to create complex visualizations, that go far beyond single axes or simple subplot grids.
This is especially true for graphics meant for publication, which are held to a higher aesthetic standard.
Still, most commonly used plotting software doesn't offer a straight-forward path to create clean custom layouts with nicely aligned axes.

Therfore, the users of basically all well-known plotting solutions often have to resort to hacks, brittle manual tweaking, or even roundtrips to Illustrator to achieve the results they want.
Common issues are overlaps, misalignments and lots of work to redo if the figure size ever changes.

Even superficially simple things like adding supertitles, sub-labels, or legends and colorbars in odd places tend to be quite difficult.
Tools that do allow for static layout optimizations usually break apart under interactive conditions, when figure size changes dynamically and content has to follow.

## Enter MakieLayout...

[MakieLayout](http://makie.juliaplots.org/stable/makielayout/tutorial.html) is a layout engine that is an attempt to solve these issues.
It is now shipped as part of the [Makie plotting ecosystem](http://makie.juliaplots.org/stable/) which is written in the Julia language.
MakieLayout allows users to assemble complex graphics or interactive visualizations using flexible grids that are highly customizable for the greatest creative freedom.
Elements can shrink or expand to fit the available space, and are always aligned in a visually pleasing way.

MakieLayout doesn't just use simple table layouts like CSS, because they only work well for simple box-like elements.
The restriction to boxes is the main reason why researchers often struggle to make nicely aligned graphics.
Instead, MakieLayout extends the table concept with _protrusions_, which describe the statically sized content "sticking out" of the main elements, like axis decorations.
Protrusions become part of the gaps between cell columns by default and don't count when calculating aspect ratios or relative column sizes.
This makes it easy to align different subplots along their axes, but also allows for unlimited tweaking, if this default mode is not the right answer.

Grid layouts can be nested to arbitrary levels, and can follow aspect ratio, absolute, or relative sizing.
This removes the need for a whole class of hacks often used to distribute elements of different sizes in visually pleasing ways.

Legends and colorbars in MakieLayout are first-class elements that are not tied to specific axes and can be freely placed anywhere.
Take a look at this totally made-up graphic, which features among other things a colorbar spanning two axes horizontally while aligning perfectly with a neighboring axis, and a legend describing three grids of 3x3 subplots each, placed in its own subsection.
The right colorbar is specifically chosen to align with the bottom content at the outer text border in order to save white-space.

![Example 1](/assets/2020-11-13-makielayout/example_1.svg)

This complex example involved no layout-tweaking whatsoever.
Elements were simply placed in appropriately nested grids, with small aesthetic adjustments of some default settings.

## Interactive and Dynamic Visualizations

Together with the interactive Makie plotting ecosystem, axes, sliders, buttons and other widgets can be combined to easily create useful applications for data visualization and exploration.
The Julia language offers very high performance so interactions are smooth and responsive.

In this short demonstration video, you can see how elements are added to and removed from a layout dynamically.
Resizing the window recalculates the layout and elements are never overlapping or otherwise misaligned.
Plots can be controlled with sliders and buttons, and via a textbox, dynamically calculated function plots are added by specifying the right half of the equation in valid Julia code:

~~~
<div class="youtube-container">
<iframe src="https://www.youtube.com/embed/C5wsl0dxGhI" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen class="youtube-video">
</iframe>
</div>
~~~

## Future Directions

As you can see, even though the Makie ecosystem is still in flux, MakieLayout can be used already to create professional and clean-looking graphics well-suited for publication.
The dynamic plotting features based on Observables are easy to use and can save a lot of time when writing quick data exploration tools.

In the future, we will focus on making the Makie ecosystem more feature complete and stable.
Right now, MakieLayout has to be specifically imported, but we're planning to use it as the default infrastructure for all 2D plots, which should make using it less verbose as well.
Although Makie can be compiled via PackageCompiler.jl, it is still a big goal to reduce the relatively long time to first plot, owing to the JIT compilation of Julia.

To get started, check out the basic [Makie tutorial here](http://makie.juliaplots.org/stable/basic-tutorial.html), and once you get the basics, have a look at the [MakieLayout tutorial here](http://makie.juliaplots.org/stable/makielayout/tutorial.html).
