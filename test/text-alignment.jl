#!/usr/bin/env julia

using Luxor

function dot(pos)
    gsave()
    sethue("red")
    circle(pos, 5, :fill)
    grestore()
end

function showt(c, p, ha, va, n)
  text(c, p, halign=ha, valign=va)
  gsave()
  setopacity(0.1)
  text(string(n), p)
  grestore()
end

function text_alignment_tests(fname)
    Drawing(1400,1400, fname)
    origin()
    setopacity(0.8)
    sethue("black")
    fontsize(65)
    tiles = Tiler(1000, 1000, 4, 3, margin=50)
    haligns = (:left, :center, :right)
    valigns = (:baseline, :top, :middle, :bottom)
    current_h = 1
    current_v = 1
    for (pos, n) in tiles
      gsave()
      h = haligns[current_h]
      v = valigns[current_v]
      dot(Point(pos))
      showt("Å˰̀Ά", pos, h, v, n)
      grestore()
      current_h += 1
      if current_h > 3
        current_v += 1
        current_h = 1
      end
      if current_v > 4
        break
      end
    end
    finish()
    println("finished test: output in $(fname)")
end

text_alignment_tests("/tmp/text-tests.pdf")