__precompile__()

"""
The Luxor package provides a set of vector drawing functions for creating graphical documents.
"""
module Luxor

using Colors, Cairo, Compat, FileIO

include("point.jl")
include("Turtle.jl")
include("polygons.jl")
include("curves.jl")
include("Tiler.jl")
include("arrows.jl")
include("text.jl")
include("blends.jl")
include("matrix.jl")
include("juliagraphics.jl")
include("animate.jl")

export Drawing, currentdrawing,
    cm, inch, mm,
    paper_sizes,
    Tiler,
    rescale,

    finish, preview,
    origin, axes, background,

    newpath, closepath, newsubpath,

    rect, box, setantialias, setline, setlinecap, setlinejoin, setdash,

    move, rmove, line, rline, arrow,

    circle, circlepath, ellipse, squircle, center3pts, curve, arc, carc, arc2r, carc2r,
    sector,

    ngon, star, pie,
    do_action, stroke, fill, paint, paint_with_alpha, fillstroke,

    Point, O, randompoint, randompointarray, midpoint, between, slope, intersection,
    intersection_line_circle, pointlinedistance, getnearestpointonline, isinside,
    perpendicular, crossproduct,
    prettypoly, polysmooth, polysplit, poly, simplify, polybbox, polycentroid,
    polysortbyangle, polysortbydistance, offsetpoly, polyfit, @polar,

    strokepreserve, fillpreserve,
    gsave, grestore,
    scale, rotate, translate,
    clip, clippreserve, clipreset,

    getpath, getpathflat,

    fontface, fontsize, text, textpath,
    textextents, textcurve, textcentred, textcentered, textright, textcurvecentered,
    setcolor, setopacity, sethue, randomhue, randomcolor, @setcolor_str,
    getmatrix, setmatrix, transform,

    Blend, setblend, blend, addstop, blendadjust,
    blendmatrix, rotationmatrix, scalingmatrix, translationmatrix,
    cairotojuliamatrix, juliatocairomatrix, getrotation, getscale, gettranslation,

    readpng, placeimage,

    julialogo, juliacircles,

    Sequence, animate

# as of version 0.4, we still share fill() and scale() with Base.

import Base: fill, scale

# basic unit conversion to Cairo/PostScript points
const inch = 72.0
const cm = 28.3464566929
const mm = 2.83464566929

type Drawing
    width::Float64
    height::Float64
    filename::String
    surface::CairoSurface
    cr::CairoContext
    surfacetype::String
    redvalue::Float64
    greenvalue::Float64
    bluevalue::Float64
    alpha::Float64
    function Drawing(w=800.0, h=800.0, f="luxor-drawing.png")
        global currentdrawing
        (path, ext)         = splitext(f)
        if ext == ".pdf"
            the_surface     =  Cairo.CairoPDFSurface(f, w, h)
            the_surfacetype = "pdf"
            the_cr          =  Cairo.CairoContext(the_surface)
        elseif ext == ".png" || ext == "" # default to PNG
            the_surface     = Cairo.CairoARGBSurface(w,h)
            the_surfacetype = "png"
            the_cr          = Cairo.CairoContext(the_surface)
        elseif ext == ".eps"
            the_surface     = Cairo.CairoEPSSurface(f, w,h)
            the_surfacetype = "eps"
            the_cr          = Cairo.CairoContext(the_surface)
        elseif ext == ".svg"
            the_surface     = Cairo.CairoSVGSurface(f, w,h)
            the_surfacetype = "svg"
            the_cr          = Cairo.CairoContext(the_surface)
        end
        # info("drawing '$f' ($w w x $h h) created in $(pwd())")
        currentdrawing      = new(w, h, f, the_surface, the_cr, the_surfacetype, 0.0, 0.0, 0.0, 1.0)
        return currentdrawing
    end
end

"""
The `paper_sizes` Dictionary holds a few paper sizes, width is first, so default is Portrait:

```
"A0"      => (2384, 3370),
"A1"      => (1684, 2384),
"A2"      => (1191, 1684),
"A3"      => (842, 1191),
"A4"      => (595, 842),
"A5"      => (420, 595),
"A6"      => (298, 420),
"A"       => (612, 792),
"Letter"  => (612, 792),
"Legal"   => (612, 1008),
"Ledger"  => (792, 1224),
"B"       => (612, 1008),
"C"       => (1584, 1224),
"D"       => (2448, 1584),
"E"       => (3168, 2448))
```
"""
paper_sizes = Dict{String, Tuple}(
  "A0"     => (2384, 3370),
  "A1"     => (1684, 2384),
  "A2"     => (1191, 1684),
  "A3"     => (842, 1191),
  "A4"     => (595, 842),
  "A5"     => (420, 595),
  "A6"     => (298, 420),
  "A"      => (612, 792),
  "Letter" => (612, 792),
  "Legal"  => (612, 1008),
  "Ledger" => (792, 1224),
  "B"      => (612, 1008),
  "C"      => (1584, 1224),
  "D"      => (2448, 1584),
  "E"      => (3168, 2448))

"""
Create a new drawing, and optionally specify file type (PNG, PDF, SVG, or EPS) and dimensions.

    Drawing()

creates a drawing, defaulting to PNG format, default filename "luxor-drawing.png",
default size 800 pixels square.

You can specify dimensions, and use the default target filename:

    Drawing(400, 300)

creates a drawing 400 pixels wide by 300 pixels high, defaulting to PNG format, default filename
"luxor-drawing.png".

    Drawing(400, 300, "my-drawing.pdf")

creates a PDF drawing in the file "my-drawing.pdf", 400 by 300 pixels.

    Drawing(1200, 800, "my-drawing.svg")`

creates an SVG drawing in the file "my-drawing.svg", 1200 by 800 pixels.

    Drawing(1200, 1200/golden, "my-drawing.eps")

creates an EPS drawing in the file "my-drawing.eps", 1200 wide by 741.8 pixels (= 1200 ÷ ϕ) high.

    Drawing("A4", "my-drawing.pdf")

creates a drawing in ISO A4 size (595 wide by 842 high) in the file "my-drawing.pdf". Other sizes available are:  "A0", "A1", "A2", "A3", "A4", "A5", "A6", "Letter", "Legal", "A", "B", "C", "D", "E". Append "landscape" to get the landscape version.

    Drawing("A4landscape")

creates the drawing A4 landscape size.

PDF files default to a white background, but PNG defaults to transparent, unless you specify
one using `background()`.
"""
function Drawing(paper_size::String, f="luxor-drawing.png")
  if contains(paper_size, "landscape")
    psize = replace(paper_size, "landscape", "")
    h, w = paper_sizes[psize]
  else
    w, h = paper_sizes[paper_size]
  end
  Drawing(w, h, f)
end

"""
    finish()

Finish the drawing, and close the file. You may be able to open it in an external viewer
application with `preview()`.
"""
function finish()
    if currentdrawing.surfacetype == "png"
        Cairo.write_to_png(currentdrawing.surface, currentdrawing.filename)
        Cairo.finish(currentdrawing.surface)
        Cairo.destroy(currentdrawing.surface)
    else
        Cairo.finish(currentdrawing.surface)
        Cairo.destroy(currentdrawing.surface)
    end
    return true
end

"""
    preview()

If working in Jupyter (IJUlia), display a PNG file in the notebook.
On macOS, open the file, which probably uses the default, Preview.app.
On Unix, open the file with `xdg-open`.
On Windows, pass the filename to the shell.
"""
function preview()
    if isdefined(Main, :IJulia) && Main.IJulia.inited && currentdrawing.surfacetype == "png"
        display(load(currentdrawing.filename))
    elseif @compat is_apple()
        run(`open $(currentdrawing.filename)`)
    elseif @compat is_windows()
        run(`$(currentdrawing.filename)`)
    elseif @compat is_unix()
        run(`xdg-open $(currentdrawing.filename)`)
    end
end

"""
    origin()

Reset the current matrix, and then set the 0/0 origin to the center of the drawing
(otherwise it will stay at the top left corner, the default).

You can refer to the 0/0 point as `O`. (O = `Point(0, 0)`),
"""
function origin()
    setmatrix([1.0, 0.0, 0.0, 1.0, 0.0, 0.0])
    Cairo.translate(currentdrawing.cr, currentdrawing.width/2.0, currentdrawing.height/2.0)
end

"""
    rescale(x, from_min, from_max, to_min, to_max)

Convert `x` from one linear scale (`from_min` to `from_max`) to another (`to_min` to `to_max`).

The scales can also be supplied in tuple form:

    rescale(x, (from_min, from_max), (to_min, to_max))

```jldoctest
julia> rescale(15, 0, 100, 0, 1)
0.15
julia> rescale(15, (0, 100), (0, 1))
0.15
julia> rescale(pi/20, 0, 2pi, 0, 1)
0.025
julia> rescale(pi/20, (0, 2pi), (0, 1))
0.025
julia> rescale(25, 0, 1, 0, 1.609344)
40.2336
julia> rescale(15, (0, 100), (1000, 0))
850.0
```
"""
rescale(x, from_min, from_max, to_min, to_max) =
    ((x - from_min) / (from_max - from_min)) * (to_max - to_min) + to_min
rescale(x, from::NTuple{2,Number}, to::NTuple{2, Number}) =
    ((x - from[1]) / (from[2] - from[1])) * (to[2] - to[1]) + to[1]

"""
Draw and label two axes lines starting at `O`, the current 0/0, and continuing out along the
current positive x and y axes.
"""
function axes()
    # draw axes
    gsave()
    setline(1)
    fontsize(20)
    sethue("gray")
    arrow(O, Point(currentdrawing.width/2.0 * 0.6, 0.0))
    text("x", Point(currentdrawing.width/2.0 * 0.6, -15.0))
    text("x", Point(30, -15))
    arrow(O, Point(0, currentdrawing.height/2.0 * 0.6))
    text("y", Point(5, currentdrawing.width/2.0 * 0.6))
    text("y", Point(5, 30))
    grestore()
end

"""
    background(color)

Fill the canvas with a single color. Returns the (red, green, blue, alpha) values.

Examples:

    background("antiquewhite")
    background("ivory")

If Colors.jl is installed:

    background(RGB(0, 0, 0))
    background(Luv(20, -20, 30))

If you don't specify a background color for a PNG drawing, the background will be
transparent. You can set a partly or completely transparent background for PNG files by
passing a color with an alpha value, such as this 'transparent black':

    background(RGBA(0, 0, 0, 0))

"""
function background(col::String)
   setcolor(col)
   paint()
   return (currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue, currentdrawing.alpha)
end

function background(col::ColorTypes.Colorant)
    temp = convert(RGBA,  col)
    setcolor(temp.r, temp.g, temp.b, temp.alpha)
    paint()
    return (currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue, currentdrawing.alpha)
end

function background(r, g, b)
    sethue(r, g, b)
    paint()
    return (currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue, currentdrawing.alpha)
end

function background(r, g, b, a)
    setcolor(r, g, b, a)
    paint()
    return (currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue, currentdrawing.alpha)
end

# I don't think this has a visible effect

"""
    setantialias(n)

Set the current antialiasing to a value between 0 and 6:

    antialias_default  = 0
    antialias_none     = 1
    antialias_gray     = 2
    antialias_subpixel = 3
    antialias_fast     = 4
    antialias_good     = 5
    antialias_best     = 6

I can't see any difference between these values. Perhaps on your machine you can!
"""
setantialias(n) = Cairo.set_antialias(currentdrawing.cr, n)

"""
    newpath()

Create a new path. This is Cairo's `new_path()` function.
"""
newpath() = Cairo.new_path(currentdrawing.cr)

"""
    newsubpath()

Add a new subpath to the current path. This is Cairo's `new_sub_path()` function. It can
be used for example to make holes in shapes.
"""
newsubpath() = Cairo.new_sub_path(currentdrawing.cr)

"""
    closepath()

Close the current path. This is Cairo's `close_path()` function.
"""
closepath() = Cairo.close_path(currentdrawing.cr)

"""
    stroke()

Stroke the current path with the current line width, line join, line cap, and dash settings.
The current path is then cleared.
"""
stroke() = Cairo.stroke(currentdrawing.cr)

"""
    fill()

Fill the current path with current settings. The current path is then cleared.
"""
fill() = Cairo.fill(currentdrawing.cr)

"""
    paint()

Paint the current clip region with the current settings.
"""
paint() = Cairo.paint(currentdrawing.cr)

"""
    strokepreserve()

Stroke the current path with current line width, line join, line cap, and dash
settings, but then keep the path current.
"""
strokepreserve()    = Cairo.stroke_preserve(currentdrawing.cr)

"""
    fillpreserve()

Fill the current path with current settings, but then keep the path current.
"""
fillpreserve()      = Cairo.fill_preserve(currentdrawing.cr)

"""
    fillstroke()

Fill and stroke the current path.
"""
function fillstroke()
    fillpreserve()
    stroke()
end

"""
    do_action(action)

This is usually called by other graphics functions. Actions for graphics commands include
`:fill`, `:stroke`, `:clip`, `:fillstroke`, `:fillpreserve`, `:strokepreserve`, `:none`, and
`:path`.
"""
function do_action(action)
    if action == :fill
        fill()
    elseif action == :stroke
        stroke()
    elseif action == :clip
        clip()
    elseif action == :fillstroke
        fillstroke()
    elseif action == :fillpreserve
        fillpreserve()
    elseif action == :strokepreserve
        strokepreserve()
    elseif action == :none
    end
    return true
end

"""
    clip()

Establish a new clipping region by intersecting the current clipping region with the
current path and then clearing the current path.
"""
clip() = Cairo.clip(currentdrawing.cr)

"""
    clippreserve()

Establish a new clipping region by intersecting the current clipping region with the current
path, but keep the current path.
"""
clippreserve() = Cairo.clip_preserve(currentdrawing.cr)

"""
    clipreset()

Reset the clipping region to the current drawing's extent.
"""
clipreset() = Cairo.reset_clip(currentdrawing.cr)

"""
    rect(xmin, ymin, w, h, action)

Create a rectangle with one corner at (`xmin`/`ymin`) with width `w` and height `h` and then
do an action.

See `box()` for more ways to do similar things, such as supplying two opposite corners,
placing by centerpoint and dimensions.
"""
function rect(xmin, ymin, w, h, action=:nothing)
    if action != :path
        newpath()
    end
    Cairo.rectangle(currentdrawing.cr, xmin, ymin, w, h)
    do_action(action)
end

"""
    rect(cornerpoint, w, h, action)

Create a rectangle with one corner at `cornerpoint` with width `w` and height `h` and do an
action.
"""
function rect(cornerpoint::Point, w, h, action)
    rect(cornerpoint.x, cornerpoint.y, w, h, action)
end

"""
    box(cornerpoint1, cornerpoint2, action=:nothing)

Create a rectangle between two points and do an action.
"""
function box(corner1::Point, corner2::Point, action=:nothing)
    rect(corner1.x, corner1.y, corner2.x - corner1.x, corner2.y - corner1.y, action)
end

"""
    box(points::Array, action=:nothing)

Create a box/rectangle using the first two points of an array of Points to defined
opposite corners.
"""
function box(bbox::Array, action=:nothing)
    box(bbox[1], bbox[2], action)
end

"""
    box(pt::Point, width, height, action=:nothing; vertices=false)

Create a box/rectangle centered at point `pt` with width and height. Use `vertices=true` to
return an array of the four corner points rather than draw the box.
"""
function box(pt::Point, width, height, action=:nothing; vertices=false)
    if vertices
        return [Point(pt.x - width/2, pt.y + height/2),
                Point(pt.x - width/2, pt.y - height/2),
                Point(pt.x + width/2, pt.y - height/2),
                Point(pt.x + width/2, pt.y + height/2)]
    end
    rect(pt.x - width/2, pt.y - height/2, width, height, action)
end

"""
    box(x, y, width, height, action=:nothing)

Create a box/rectangle centered at point `x/y` with width and height.
"""
function box(x, y, width, height, action=:nothing)
    rect(x - width/2.0, y - height/2.0, width, height, action)
end

"""
    setline(n)

Set the line width.
"""
setline(n) = Cairo.set_line_width(currentdrawing.cr, n)

"""
    setlinecap(s)

Set the line ends. `s` can be "butt" (the default), "square", or "round".
"""
function setlinecap(str="butt")
    if str == "round"
        Cairo.set_line_cap(currentdrawing.cr, Cairo.CAIRO_LINE_CAP_ROUND)
    elseif str == "square"
        Cairo.set_line_cap(currentdrawing.cr, Cairo.CAIRO_LINE_CAP_SQUARE)
    else
        Cairo.set_line_cap(currentdrawing.cr, Cairo.CAIRO_LINE_CAP_BUTT)
    end
end

"""
    setlinejoin("miter")
    setlinejoin("round")
    setlinejoin("bevel")

Set the line join style, or how to render the junction of two lines when stroking.
"""
function setlinejoin(str="miter")
    if str == "round"
        Cairo.set_line_join(currentdrawing.cr, Cairo.CAIRO_LINE_JOIN_ROUND)
    elseif str == "bevel"
        Cairo.set_line_join(currentdrawing.cr, Cairo.CAIRO_LINE_JOIN_BEVEL)
    else
        Cairo.set_line_join(currentdrawing.cr, Cairo.CAIRO_LINE_JOIN_MITER)
    end
end

"""
    setlinedash("dot")

Set the dash pattern to one of: "solid", "dotted", "dot", "dotdashed", "longdashed",
"shortdashed", "dash", "dashed", "dotdotdashed", "dotdotdotdashed"
"""
function setdash(dashing)
    Cairo.set_line_type(currentdrawing.cr, dashing)
end

"""
    move(x, y)
    move(pt)

Move to a point.
"""
move(x, y)      = Cairo.move_to(currentdrawing.cr,x, y)
move(pt)        = move(pt.x, pt.y)

"""
    rmove(x, y)

Move by an amount from the current point. Move relative to current position by `x` and `y`:

Move relative to current position by the `pt`'s x and y:

    rmove(pt)
"""
rmove(x, y)     = Cairo.rel_move_to(currentdrawing.cr,x, y)
rmove(pt)       = rmove(pt.x, pt.y)

"""
    line(x, y)
    line(x, y, :action)
    line(pt)

Create a line from the current position to the `x/y` position and optionally apply an action:
"""
line(x, y)      = Cairo.line_to(currentdrawing.cr,x, y)
line(pt)        = line(pt.x, pt.y)

"""
    line(pt1::Point, pt2::Point, action=:nothing)

Make a line between two points, `pt1` and `pt2` and do an action.
"""
function line(pt1::Point, pt2::Point, action=:nothing)
    move(pt1)
    line(pt2)
    do_action(action)
end

"""
    rline(x, y)
    rline(x, y, :action)
    rline(pt)

Create a line relative to the current position to the `x/y` position and optionally apply an
action:
"""
rline(x, y)     = Cairo.rel_line_to(currentdrawing.cr,x, y)
rline(pt)       = rline(pt.x, pt.y)

saved_colors = Tuple{Float64,Float64,Float64,Float64}[]

# I originally used simple Cairo save() but the colors/opacity
# thing I've got going didn't save/restore properly, hence the stack
"""
    gsave()

Save the current color settings on the stack.
"""
function gsave()
    Cairo.save(currentdrawing.cr)
    push!(saved_colors,
        (currentdrawing.redvalue,
         currentdrawing.greenvalue,
         currentdrawing.bluevalue,
         currentdrawing.alpha))
end

"""
    grestore()

Replace the current graphics state with the one on top of the stack.
"""
function grestore()
    Cairo.restore(currentdrawing.cr)
    try
    (currentdrawing.redvalue,
     currentdrawing.greenvalue,
     currentdrawing.bluevalue,
     currentdrawing.alpha) = pop!(saved_colors)
     catch err
         println("$err Not enough colors on the stack to restore.")
    end
end

"""
    scale(x, y)

Scale workspace by `x` and `y`.

Example:

    scale(0.2, 0.3)

"""

scale(sx, sy) = Cairo.scale(currentdrawing.cr, sx, sy)

"""
    rotate(a)

Rotate workspace by `a` radians clockwise (from positive x-axis to positive y-axis).
"""

rotate(a) = Cairo.rotate(currentdrawing.cr, a)

"""
    translate(x, y)
    translate(point)

Translate the workspace by `x` and `y` or by moving the origin to `pt`.
"""

translate(tx, ty)        = Cairo.translate(currentdrawing.cr, tx, ty)
translate(pt::Point)     = translate(pt.x, pt.y)

"""
    getpath()

Get the current path and return a CairoPath object, which is an array of `element_type` and
`points` objects. With the results you can step through and examine each entry:

```
o = getpath()
for e in o
      if e.element_type == Cairo.CAIRO_PATH_MOVE_TO
          (x, y) = e.points
          move(x, y)
      elseif e.element_type == Cairo.CAIRO_PATH_LINE_TO
          (x, y) = e.points
          # straight lines
          line(x, y)
          stroke()
          circle(x, y, 1, :stroke)
      elseif e.element_type == Cairo.CAIRO_PATH_CURVE_TO
          (x1, y1, x2, y2, x3, y3) = e.points
          # Bezier control lines
          circle(x1, y1, 1, :stroke)
          circle(x2, y2, 1, :stroke)
          circle(x3, y3, 1, :stroke)
          move(x, y)
          curve(x1, y1, x2, y2, x3, y3)
          stroke()
          (x, y) = (x3, y3) # update current point
      elseif e.element_type == Cairo.CAIRO_PATH_CLOSE_PATH
          closepath()
      else
          error("unknown CairoPathEntry " * repr(e.element_type))
          error("unknown CairoPathEntry " * repr(e.points))
      end
  end
```
"""
getpath()      = Cairo.convert_cairo_path_data(Cairo.copy_path(currentdrawing.cr))

"""
    getpathflat()

Get the current path, like `getpath()` but flattened so that there are no Bèzier curves.

Returns a CairoPath which is an array of `element_type` and `points` objects.
"""
getpathflat()  = Cairo.convert_cairo_path_data(Cairo.copy_path_flat(currentdrawing.cr))

"""
    setcolor("gold")
    setcolor("darkturquoise")

Set the current color to a named color. This use the definitions in Colors.jl to convert a
string to RGBA eg setcolor("gold") # or "green", "darkturquoise", "lavender", etc. The list
is at `Colors.color_names`.

Use `sethue()` for changing colors without changing current opacity level.

`sethue()` and `setcolor()` return the three or four values that were used:

    julia> setcolor(sethue("red")..., .8)

    (1.0,0.0,0.0,0.8)

    julia> sethue(setcolor("red")[1:3]...)

    (1.0,0.0,0.0)
"""
function setcolor(col::String)
    temp = parse(RGBA, col)
    currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue,
        currentdrawing.alpha = temp.r, temp.g, temp.b, temp.alpha
    Cairo.set_source_rgba(currentdrawing.cr, currentdrawing.redvalue,
        currentdrawing.greenvalue, currentdrawing.bluevalue, temp.alpha)
    return (currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue, currentdrawing.alpha)
end

"""
    setcolor(r, g, b)
    setcolor(r, g, b, alpha)
    setcolor(color)
    setcolor(col::ColorTypes.Colorant)

Set the current color.

Examples:

    setcolor(convert(Colors.HSV, Colors.RGB(0.5, 1, 1)))
    setcolor(.2, .3, .4, .5)
    setcolor(convert(Colors.HSV, Colors.RGB(0.5, 1, 1)))

    for i in 1:15:360
       setcolor(convert(Colors.RGB, Colors.HSV(i, 1, 1)))
       ...
    end
"""
function setcolor(col::ColorTypes.Colorant)
  temp = convert(RGBA, col)
  setcolor(temp.r, temp.g, temp.b)
  return (currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue, currentdrawing.alpha)
end

function setcolor(r, g, b, a=1)
    currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue,
      currentdrawing.alpha = r, g, b, a
    Cairo.set_source_rgba(currentdrawing.cr, r, g, b, a)
    return (r, g, b, a)
end

"""
Set the current color to a string.

For example:

    setcolor"red"
"""
macro setcolor_str(ex)
    isa(ex, String) || error("colorant requires literal strings")
    col = parse(RGBA, ex)
    quote
    currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue,
      currentdrawing.alpha = $col.r, $col.g, $col.b, $col.alpha
    Cairo.set_source_rgba(currentdrawing.cr, currentdrawing.redvalue,
      currentdrawing.greenvalue, currentdrawing.bluevalue, $col.alpha)
    end
end

"""
    sethue("black")
    sethue(0.3,0.7,0.9)

Set the color without changing opacity.

`sethue()` is like `setcolor()`, but we sometimes want to change the current 'color' without
changing alpha/opacity. Using `sethue()` rather than `setcolor()` doesn't change the current
alpha opacity.
"""
function sethue(col::String)
    temp = parse(RGBA,  col)
    currentdrawing.redvalue, currentdrawing.greenvalue,
        currentdrawing.bluevalue = temp.r, temp.g, temp.b
    # use current alpha, not incoming one
    Cairo.set_source_rgba(currentdrawing.cr, currentdrawing.redvalue,
        currentdrawing.greenvalue, currentdrawing.bluevalue, currentdrawing.alpha)
    return (currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue)
end

"""
    sethue(col::ColorTypes.Colorant)

Set the color without changing current opacity:
"""
function sethue(col::ColorTypes.Colorant)
    temp = convert(RGBA,  col)
    currentdrawing.redvalue, currentdrawing.greenvalue,
        currentdrawing.bluevalue = temp.r, temp.g, temp.b
    # use current alpha
    Cairo.set_source_rgba(currentdrawing.cr, temp.r, temp.g, temp.b, currentdrawing.alpha)
    return (currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue)
end

"""
    sethue(0.3, 0.7, 0.9)

Set the color's `r`, `g`, `b` values. Use `setcolor(r,g,b,a)` to set transparent colors.
"""
function sethue(r, g, b)
    currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue = r, g, b
    # use current alpha
    Cairo.set_source_rgba(currentdrawing.cr, r, g, b, currentdrawing.alpha)
    return (currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue)
end

"""
    setopacity(alpha)

Set the current opacity to a value between 0 and 1. This modifies the alpha value of the
current color.
"""
function setopacity(a)
    # use current RGB values
    currentdrawing.alpha = a
    Cairo.set_source_rgba(currentdrawing.cr, currentdrawing.redvalue,
        currentdrawing.greenvalue, currentdrawing.bluevalue, currentdrawing.alpha)
    return a
end

"""
    randomhue()

Set a random hue.

Choose a random color without changing the current alpha opacity.
"""
function randomhue()
  rrand, grand, brand = rand(3)
  sethue(rrand, grand, brand)
  return (currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue)
end

"""
    randomcolor()

Set a random color. This may change the current alpha opacity too.
"""
function randomcolor()
  rrand, grand, brand, arand = rand(4)
  setcolor(rrand, grand, brand, arand)
  return (currentdrawing.redvalue, currentdrawing.greenvalue, currentdrawing.bluevalue, currentdrawing.alpha)
end

"""
    readpng(pathname)

Read a PNG file.

This returns a image object suitable for placing on the current drawing with `placeimage()`.
You can access its `width` and `height` fields:

    image = readpng("/tmp/test-image.png")
    w = image.width
    h = image.height
"""
function readpng(pathname)
    return Cairo.read_from_png(pathname)
end

function paint_with_alpha(ctx::Cairo.CairoContext, a = 0.5)
    Cairo.paint_with_alpha(currentdrawing.cr, a)
end

"""
    placeimage(img, xpos, ypos)

Place a PNG image on the drawing at (`xpos`/`ypos`). The image `img` has been previously
loaded using `readpng()`.
"""
function placeimage(img::Cairo.CairoSurface, xpos, ypos)
    Cairo.set_source_surface(currentdrawing.cr, img, xpos, ypos)
    # no alpha
    Cairo.paint(currentdrawing.cr)
end

"""
    placeimage(img, pos)

Place a PNG image on the drawing at `pos`.
"""
placeimage(img::Cairo.CairoSurface, pt::Point) = placeimage(img, pt.x, pt.y)

"""
    placeimage(img, xpos, ypos, a)

Place a PNG image on the drawing at (`xpos`/`ypos`) with transparency `a`.
"""
function placeimage(img::Cairo.CairoSurface, xpos, ypos, alpha)
    Cairo.set_source_surface(currentdrawing.cr, img, xpos, ypos)
    paint_with_alpha(currentdrawing.cr, alpha)
end

"""
    placeimage(img, pos, a)

Place a PNG image on the drawing at `pos` with transparency `a`.
"""
placeimage(img::Cairo.CairoSurface, pt::Point, alpha) =
  placeimage(img::Cairo.CairoSurface, pt.x, pt.y, alpha)

end
# module
