#import "@preview/cetz:0.3.3": canvas, draw

#let force-arrow(from, to, label, label-pos, color: white) = {
  draw.line(from, to, stroke: color, mark: (end: ">"))
  draw.content(label-pos, label)
}

#let vector-end(origin, angle, length) = {
  (
    origin.at(0) + length * calc.cos(angle),
    origin.at(1) + length * calc.sin(angle),
  )
}

#let vector-force(
  origin,
  angle,
  length,
  label,
  label-dx: 0.25,
  label-dy: 0.25,
  color: white,
) = {
  let to = vector-end(origin, angle, length)
  draw.line(origin, to, stroke: color, mark: (end: ">"))
  draw.content((to.at(0) + label-dx, to.at(1) + label-dy), label)
}

#let force-side-sign(side) = if side == "left" { -1 } else { 1 }

#let force-side-angle(side, angle) = if side == "left" {
  180deg - angle
} else {
  angle
}

#let applied-force(
  label,
  side: "right",
  angle: 0deg,
  length: 1.85,
  angle-label: none,
  label-dx: auto,
  label-dy: 0.2,
  color: none,
) = (
  label: label,
  side: side,
  angle: angle,
  length: length,
  angle-label: angle-label,
  label-dx: label-dx,
  label-dy: label-dy,
  color: color,
)

#let draw-applied-force(center, force, default-color) = {
  let side = force.at("side")
  let angle = force.at("angle")
  let sign = force-side-sign(side)
  let direction = force-side-angle(side, angle)
  let label-dx = if force.at("label-dx") == auto {
    sign * 0.25
  } else {
    force.at("label-dx")
  }
  let color = if force.at("color") == none {
    default-color
  } else {
    force.at("color")
  }

  vector-force(
    center,
    direction,
    force.at("length"),
    force.at("label"),
    label-dx: label-dx,
    label-dy: force.at("label-dy"),
    color: color,
  )

  if force.at("angle-label") != none {
    let arc-start = if side == "left" { 180deg } else { 0deg }
    let arc-delta = if side == "left" { -angle } else { angle }
    draw.content(
      (
        center.at(0) + 0.78 * calc.cos(arc-start + arc-delta / 2),
        center.at(1) + 0.78 * calc.sin(arc-start + arc-delta / 2),
      ),
      force.at("angle-label"),
    )
    draw.arc(center, radius: 0.55, start: arc-start, delta: arc-delta, stroke: color)
  }
}

#let vforce(x, y1, y2, label, dx: 0.3, dy: 0, color: white) = {
  draw.line((x, y1), (x, y2), stroke: color, mark: (end: ">"))
  draw.content((x + dx, (y1 + y2) / 2 + dy), label)
}

#let hforce(x1, x2, y, label, dx: 0, dy: 0.3, color: white) = {
  draw.line((x1, y), (x2, y), stroke: color, mark: (end: ">"))
  draw.content(((x1 + x2) / 2 + dx, y + dy), label)
}

#let position-line(
  x1: 2,
  x2: 5,
  axis-start: -0.5,
  axis-end: 7,
  color: white,
  delta-color: blue,
) = {
  draw.line((axis-start, 0), (axis-end, 0), stroke: color, mark: (end: ">"))
  draw.content((axis-end + 0.25, 0), [$x$])

  draw.circle((x1, 0), radius: 0.06, fill: color, stroke: color)
  draw.content((x1, 0.35), [$x(t_1)$])
  draw.line((x1, 0.1), (x1, -0.1), stroke: color)
  draw.content((x1, -0.35), [$t_1$])

  draw.circle((x2, 0), radius: 0.06, fill: color, stroke: color)
  draw.content((x2, 0.35), [$x(t_2)$])
  draw.line((x2, 0.1), (x2, -0.1), stroke: color)
  draw.content((x2, -0.35), [$t_2$])

  draw.line((x1, 0.7), (x2, 0.7), stroke: delta-color, mark: (end: ">"))
  draw.content(((x1 + x2) / 2, 1.0), [$Delta x$])
}

#let axes(
  x-min: -0.3,
  x-max: 5,
  y-min: 0,
  y-max: 13,
  x-label: [$t " (s)"$],
  y-label: [$x " (m)"$],
  color: white,
) = {
  draw.line((x-min, 0), (x-max, 0), stroke: color, mark: (end: ">"))
  draw.content((x-max + 0.25, 0), x-label)
  draw.line((0, y-min), (0, y-max), stroke: color, mark: (end: ">"))
  draw.content((0, y-max + 0.35), y-label)
}

#let tick-labels(xs: (), ys: (), color: white) = {
  for x in xs {
    draw.content((x, -0.35), [$#x$])
  }
  for y in ys {
    draw.content((-0.25, y), [$#y$])
  }
}

#let plane-axes(
  x-min: -5,
  x-max: 5,
  y-min: -5,
  y-max: 5,
  x-label: [$x$],
  y-label: [$y$],
  color: white,
) = {
  draw.line((x-min, 0), (x-max, 0), stroke: color, mark: (end: ">"))
  draw.content((x-max + 0.25, 0), x-label)
  draw.line((0, y-min), (0, y-max), stroke: color, mark: (end: ">"))
  draw.content((0, y-max + 0.25), y-label)
}

#let domain-circle(
  radius: 3,
  inside: true,
  strict: false,
  x-min: -5,
  x-max: 5,
  y-min: -5,
  y-max: 5,
  label: none,
  color: white,
  graph-color: blue,
  shade-color: blue.lighten(55%),
) = {
  plane-axes(x-min: x-min, x-max: x-max, y-min: y-min, y-max: y-max, color: color)
  if inside {
    draw.circle((0, 0), radius: radius, fill: shade-color, stroke: graph-color + 1pt)
  } else {
    for y in range(int(y-min), int(y-max) + 1) {
      let yy = y
      if calc.abs(yy) >= radius {
        draw.line((x-min, yy), (x-max, yy), stroke: shade-color + 0.6pt)
      } else {
        let dx = calc.sqrt(radius * radius - yy * yy)
        draw.line((x-min, yy), (-dx, yy), stroke: shade-color + 0.6pt)
        draw.line((dx, yy), (x-max, yy), stroke: shade-color + 0.6pt)
      }
    }
    draw.circle((0, 0), radius: radius, stroke: graph-color + 1pt)
  }
  if strict {
    draw.content((radius + 0.45, 0.35), [$"$fronteira excluída$"$])
  }
  if label != none {
    draw.content((0, y-max + 0.65), label)
  }
}

#let domain-half-plane-y-lt-x(
  x-min: -5,
  x-max: 5,
  y-min: -5,
  y-max: 5,
  color: white,
  graph-color: blue,
  shade-color: blue.lighten(55%),
) = {
  plane-axes(x-min: x-min, x-max: x-max, y-min: y-min, y-max: y-max, color: color)
  for x in range(int(x-min), int(x-max) + 1) {
    draw.line((x, y-min), (x, x), stroke: shade-color + 0.6pt)
  }
  draw.line((x-min, x-min), (x-max, x-max), stroke: graph-color + 1pt)
  draw.content((2.8, 2.25), [$y = x$])
  draw.content((1.6, -2.8), [$y < x$])
}

#let domain-between-diagonals(
  x-min: -5,
  x-max: 5,
  y-min: -5,
  y-max: 5,
  color: white,
  graph-color: blue,
  shade-color: blue.lighten(55%),
) = {
  plane-axes(x-min: x-min, x-max: x-max, y-min: y-min, y-max: y-max, color: color)
  for x in range(int(x-min), int(x-max) + 1) {
    let top = calc.abs(x)
    draw.line((x, -top), (x, top), stroke: shade-color + 0.6pt)
  }
  draw.line((x-min, x-min), (x-max, x-max), stroke: graph-color + 1pt)
  draw.line((x-min, -x-min), (x-max, -x-max), stroke: graph-color + 1pt)
  draw.content((2.9, 2.25), [$y = x$])
  draw.content((2.8, -2.25), [$y = -x$])
  draw.content((2.4, 0.45), [$y^2 < x^2$])
}

#let domain-ellipse(
  a: 3,
  b: 1,
  inside: true,
  strict: true,
  x-min: -5,
  x-max: 5,
  y-min: -3,
  y-max: 3,
  color: white,
  graph-color: blue,
  shade-color: blue.lighten(55%),
) = {
  plane-axes(x-min: x-min, x-max: x-max, y-min: y-min, y-max: y-max, color: color)
  let k = 0.55228475
  if inside {
    draw.bezier((a, 0), (a, k * b), (k * a, b), (0, b), stroke: graph-color + 1pt)
    draw.bezier((0, b), (-k * a, b), (-a, k * b), (-a, 0), stroke: graph-color + 1pt)
    draw.bezier((-a, 0), (-a, -k * b), (-k * a, -b), (0, -b), stroke: graph-color + 1pt)
    draw.bezier((0, -b), (k * a, -b), (a, -k * b), (a, 0), stroke: graph-color + 1pt)
    for x in range(-int(a), int(a) + 1) {
      let yy = b * calc.sqrt(1 - x * x / (a * a))
      draw.line((x, -yy), (x, yy), stroke: shade-color + 0.6pt)
    }
  }
  if strict {
    draw.content((0, y-min - 0.45), [$"$fronteira excluída$"$])
  }
  draw.content((0, 0), [$frac(x^2, #a * #a) + frac(y^2, #b * #b) < 1$])
}

#let linear-xt-graph(
  slope: 2,
  intercept: 3,
  x-max: 4,
  y-min: 0,
  y-max: 13,
  highlight-x: 4,
  highlight-y: 11,
  xs: (1, 2, 3, 4),
  ys: (3, 11),
  color: white,
  graph-color: blue,
  guide-color: gray,
) = {
  axes(x-max: x-max + 1, y-min: y-min, y-max: y-max, color: color)
  draw.line((0, intercept), (x-max, intercept + slope * x-max), stroke: graph-color)
  draw.line((highlight-x, 0), (highlight-x, highlight-y), stroke: guide-color)
  draw.line((0, highlight-y), (highlight-x, highlight-y), stroke: guide-color)
  tick-labels(xs: xs, ys: ys, color: color)
}

#let parabola-xt-graph(
  x-max: 3,
  y-min: -0.5,
  y-max: 10.5,
  highlight-x: 3,
  highlight-y: 9,
  xs: (1, 2, 3),
  ys: (1, 4, 9),
  color: white,
  graph-color: blue,
  guide-color: gray,
) = {
  axes(x-max: x-max + 1, y-min: y-min, y-max: y-max, color: color)
  draw.bezier((0, 0), (1, 0), (2, 4), (3, 9), stroke: graph-color)
  draw.line((highlight-x, 0), (highlight-x, highlight-y), stroke: guide-color)
  draw.line((0, highlight-y), (highlight-x, highlight-y), stroke: guide-color)
  tick-labels(xs: xs, ys: ys, color: color)
}

#let linear-vt-graph(
  slope: 2,
  x-max: 4.5,
  y-min: -0.5,
  y-max: 10,
  label: [$v(t) = 2t$],
  xs: (1, 2, 3, 4),
  ys: (2, 4, 6, 8),
  color: white,
  graph-color: blue,
) = {
  axes(
    x-max: x-max + 0.5,
    y-min: y-min,
    y-max: y-max,
    x-label: [$t " (s)"$],
    y-label: [$v " (m/s)"$],
    color: color,
  )
  draw.line((0, 0), (x-max, slope * x-max), stroke: graph-color)
  draw.content((x-max - 0.4, slope * x-max - 0.4), label)
  tick-labels(xs: xs, ys: ys, color: color)
}

#let force-components-diagram(color: white) = {
  draw.line((-3, 0), (3, 0), stroke: color, mark: (end: ">"))
  draw.content((3.25, 0), [$x$])
  draw.line((0, -3), (0, 3), stroke: color, mark: (end: ">"))
  draw.content((0, 3.25), [$y$])

  force-arrow((0, 0), (-1.2, 1.6), [$arrow(F)_1$], (-1.65, 1.8), color: color)
  force-arrow((0, 0), (2, 0), [$arrow(F)_2$], (2.25, 0.25), color: color)
  force-arrow((0, 0), (0, -2), [$arrow(F)_3$], (0.35, -2), color: color)

  draw.arc((0, 0), radius: 0.6, start: 127deg, delta: 53deg, stroke: color)
  draw.content((-0.85, 0.35), [$53 degree$])
  draw.circle((0, 0), radius: 0.05, fill: color, stroke: color)
}

#let block-horizontal(
  label: none,
  applied-label: none,
  friction-label: none,
  normal-label: none,
  weight-label: none,
  applied-side: "right",
  applied-angle: 0deg,
  applied-length: 1.85,
  friction-side: "left",
  friction-length: 1.15,
  normal-length: 1.25,
  weight-length: 1.25,
  applied-angle-label: none,
  force-origin: none,
  axes: false,
  x-label: [$x$],
  y-label: [$y$],
  color: white,
  ..applied-forces
) = {
  let center = if force-origin == none { (2, 0.75) } else { force-origin }
  draw.line((-1, 0), (4, 0), stroke: color)
  draw.rect((1, 0), (3, 1.5), stroke: color)
  if label != none {
    draw.content((2, 0.75), label)
  }
  if axes {
    draw.line((-0.75, center.at(1)), (4.25, center.at(1)), stroke: color, mark: (end: ">"))
    draw.content((4.5, center.at(1)), x-label)
    draw.line((center.at(0), -1.2), (center.at(0), 2.85), stroke: color, mark: (end: ">"))
    draw.content((center.at(0), 3.1), y-label)
  }
  if applied-label != none {
    draw-applied-force(
      center,
      applied-force(
      applied-label,
        side: applied-side,
        angle: applied-angle,
        length: applied-length,
        angle-label: applied-angle-label,
      ),
      color,
    )
  }
  for force in applied-forces.pos() {
    draw-applied-force(center, force, color)
  }
  if friction-label != none {
    let friction-sign = force-side-sign(friction-side)
    vector-force(
      center,
      if friction-side == "left" { 180deg } else { 0deg },
      friction-length,
      friction-label,
      label-dx: friction-sign * 0.55,
      label-dy: 0.25,
      color: color,
    )
  }
  if normal-label != none {
    vector-force(
      center,
      90deg,
      normal-length,
      normal-label,
      label-dx: 0.22,
      label-dy: 0.05,
      color: color,
    )
  }
  if weight-label != none {
    vector-force(
      center,
      -90deg,
      weight-length,
      weight-label,
      label-dx: 0.22,
      label-dy: -0.05,
      color: color,
    )
  }
}

#let hanging-mass(
  label: none,
  tension-label: none,
  weight-label: none,
  origin: (0, 3.5),
  rope-length: 2.0,
  radius: 0.35,
  color: white,
) = {
  let x = origin.at(0)
  let y = origin.at(1)
  let center = (x, y - rope-length - radius)
  draw.line(origin, (x, y - rope-length), stroke: color)
  draw.circle(center, radius: radius, stroke: color)
  if label != none {
    draw.content(center, label)
  }
  if tension-label != none {
    vforce(x - radius - 0.35, center.at(1), center.at(1) + 1.0, tension-label, dx: -0.35, dy: 0, color: color)
  }
  if weight-label != none {
    vforce(x + radius + 0.35, center.at(1), center.at(1) - 1.0, weight-label, dx: 0.35, dy: 0, color: color)
  }
}

#let inclined-plane(
  block-label: none,
  tension-label: none,
  weight-label: none,
  normal-label: none,
  angle: 15deg,
  color: white,
) = {
  draw.line((0, 0), (5, 0), stroke: color)
  draw.line((0, 0), (5, 1.5), stroke: color)
  draw.line((5, 0), (5, 1.5), stroke: color)
  draw.rect((2.1, 0.85), (3.1, 1.45), stroke: color)
  if block-label != none {
    draw.content((2.6, 1.15), block-label)
  }
  if tension-label != none {
    force-arrow((3.1, 1.45), (4.2, 1.95), tension-label, (4.45, 2.05), color: color)
  }
  if weight-label != none {
    vforce(2.6, 0.85, -0.25, weight-label, dx: 0.35, dy: 0, color: color)
  }
  if normal-label != none {
    force-arrow((2.6, 1.45), (2.2, 2.45), normal-label, (2.0, 2.65), color: color)
  }
  draw.content((0.75, 0.16), [$#angle$])
}

#let trajectory-r-t-example(color: white, graph-color: blue, guide-color: gray) = {
  plane-axes(x-min: -0.4, x-max: 4.8, y-min: -0.4, y-max: 10, x-label: [$x " (m)"$], y-label: [$y " (m)"$], color: color)
  draw.line((1, 0), (1.5, 0.25), stroke: graph-color + 1pt)
  draw.line((1.5, 0.25), (2, 1), stroke: graph-color + 1pt)
  draw.line((2, 1), (2.5, 2.25), stroke: graph-color + 1pt)
  draw.line((2.5, 2.25), (3, 4), stroke: graph-color + 1pt)
  draw.line((3, 4), (3.5, 6.25), stroke: graph-color + 1pt)
  draw.line((3.5, 6.25), (4, 9), stroke: graph-color + 1pt)
  for p in ((1, 0), (2, 1), (3, 4), (4, 9)) {
    draw.circle(p, radius: 0.06, fill: color, stroke: color)
    draw.line((p.at(0), 0), p, stroke: guide-color + 0.5pt)
    draw.line((0, p.at(1)), p, stroke: guide-color + 0.5pt)
    draw.content((p.at(0), -0.35), [$#(p.at(0))$])
    draw.content((-0.25, p.at(1)), [$#(p.at(1))$])
  }
  draw.content((4.25, 9), [$arrow(r)(t)$])
}

#let displacement-vector-example(color: white, vector-color: blue, guide-color: gray) = {
  plane-axes(x-min: -0.4, x-max: 2.4, y-min: -0.4, y-max: 2.6, color: color)
  draw.line((0, 0), (1, 2.2), stroke: vector-color + 1pt, mark: (end: ">"))
  draw.line((1, 0), (1, 2.2), stroke: guide-color + 0.6pt)
  draw.line((0, 2.2), (1, 2.2), stroke: guide-color + 0.6pt)
  draw.content((1.15, 2.2), [$arrow(r)(2)$])
  draw.content((1, -0.35), [$1$])
  draw.content((-0.25, 2.2), [$2.2$])
}

#let distance-rr2-diagram(color: white, vector-color: blue, guide-color: gray) = {
  plane-axes(x-min: -0.5, x-max: 4.5, y-min: -0.5, y-max: 3.5, color: color)
  let p = (0.8, 0.7)
  let q = (3.8, 2.7)
  draw.circle(p, radius: 0.07, fill: color, stroke: color)
  draw.circle(q, radius: 0.07, fill: color, stroke: color)
  draw.line(p, q, stroke: vector-color + 1pt)
  draw.line(p, (q.at(0), p.at(1)), stroke: guide-color + 0.7pt)
  draw.line((q.at(0), p.at(1)), q, stroke: guide-color + 0.7pt)
  draw.content((0.55, 0.35), [$P(p,q)$])
  draw.content((3.95, 2.85), [$X(x,y)$])
  draw.content((2.2, 0.42), [$x - p$])
  draw.content((4.1, 1.65), [$y - q$])
  draw.content((2.15, 2.0), [$d(P,X)$])
}

#let distance-rrn-diagram(color: white, vector-color: blue) = {
  draw.line((-0.2, 0), (4.8, 0), stroke: color, mark: (end: ">"))
  draw.line((0, -0.2), (0, 2.8), stroke: color, mark: (end: ">"))
  draw.line((0, 0), (-1.2, -1.0), stroke: color, mark: (end: ">"))
  draw.content((5.05, 0), [$x_1$])
  draw.content((0, 3.05), [$x_2$])
  draw.content((-1.45, -1.2), [$x_n$])
  draw.line((0.8, 0.6), (3.6, 2.15), stroke: vector-color + 1pt)
  draw.circle((0.8, 0.6), radius: 0.07, fill: color, stroke: color)
  draw.circle((3.6, 2.15), radius: 0.07, fill: color, stroke: color)
  draw.content((0.45, 0.35), [$P$])
  draw.content((3.85, 2.25), [$X$])
  draw.content((2.25, 1.55), [$sqrt(sum_(i=1)^n (x_i - p_i)^2)$])
}

#let scalar-surface-sketch(color: white, graph-color: blue, guide-color: gray) = {
  draw.line((0, 0), (4.8, 0), stroke: color, mark: (end: ">"))
  draw.line((0, 0), (-1.5, -1.0), stroke: color, mark: (end: ">"))
  draw.line((0, 0), (0, 3.3), stroke: color, mark: (end: ">"))
  draw.content((5.05, 0), [$x$])
  draw.content((-1.75, -1.12), [$y$])
  draw.content((0, 3.55), [$z$])
  for i in range(0, 5) {
    let a = i / 4
    draw.bezier((0.4 + a * 2.9, -0.15 - a * 0.55), (1.2 + a * 2.2, 0.4 + a * 0.3), (2.5 + a * 1.3, 1.0 + a * 0.55), (3.8 + a * 0.2, 1.25 + a * 0.7), stroke: graph-color + 0.6pt)
    draw.bezier((0.4 + a * 0.7, -0.15 + a * 1.4), (1.3 + a * 0.8, 0.15 + a * 1.2), (2.5 + a * 0.7, 0.55 + a * 0.95), (3.8 + a * 0.2, 1.25 + a * 0.7), stroke: graph-color + 0.6pt)
  }
  draw.line((2.6, 0.35), (2.6, 1.55), stroke: guide-color + 0.7pt)
  draw.content((2.85, 1.55), [$z = f(x,y)$])
}

#let derivative-1d-sketch(color: white, graph-color: blue, tangent-color: red) = {
  axes(x-min: -0.4, x-max: 4.5, y-min: -0.4, y-max: 4.5, x-label: [$x$], y-label: [$y$], color: color)
  draw.bezier((0.4, 0.3), (1.2, 0.45), (2.1, 2.7), (4.1, 3.8), stroke: graph-color + 1pt)
  draw.line((1.45, 1.25), (3.45, 3.25), stroke: tangent-color + 1pt)
  draw.circle((2.35, 2.15), radius: 0.07, fill: color, stroke: color)
  draw.content((3.6, 3.35), [$f'(x_0)$])
  draw.content((2.2, -0.35), [$x_0$])
}

#let partial-derivative-slice(color: white, graph-color: blue, slice-color: red) = {
  scalar-surface-sketch(color: color, graph-color: graph-color)
  draw.line((1.0, -0.35), (3.65, 1.9), stroke: slice-color + 1pt)
  draw.line((2.35, 0.8), (3.15, 1.55), stroke: slice-color + 1pt, mark: (end: ">"))
  draw.content((3.25, 1.7), [$g'(x)=f_x(x,c)$])
  draw.content((1.05, -0.65), [$y=c$])
}

#let basis-ijk-diagram(color: white, vector-color: blue) = {
  draw.line((0, 0), (3.4, 0), stroke: color, mark: (end: ">"))
  draw.line((0, 0), (-1.4, -1.0), stroke: color, mark: (end: ">"))
  draw.line((0, 0), (0, 3.2), stroke: color, mark: (end: ">"))
  draw.content((3.65, 0), [$x$])
  draw.content((-1.65, -1.15), [$y$])
  draw.content((0, 3.45), [$z$])
  draw.line((0, 0), (1.2, 0), stroke: vector-color + 1pt, mark: (end: ">"))
  draw.line((0, 0), (-0.7, -0.5), stroke: vector-color + 1pt, mark: (end: ">"))
  draw.line((0, 0), (0, 1.2), stroke: vector-color + 1pt, mark: (end: ">"))
  draw.content((1.35, 0.2), [$arrow(i)$])
  draw.content((-1.0, -0.65), [$arrow(j)$])
  draw.content((0.25, 1.25), [$arrow(k)$])
}

#let riemann-integral-1d(color: white, graph-color: blue, rect-color: gray) = {
  axes(x-min: -0.3, x-max: 5.2, y-min: -0.3, y-max: 4.2, x-label: [$x$], y-label: [$f(x)$], color: color)
  for i in range(0, 5) {
    let x1 = 0.6 + i * 0.75
    let x2 = x1 + 0.75
    let h = 1.0 + 0.35 * i
    draw.rect((x1, 0), (x2, h), stroke: rect-color + 0.7pt)
  }
  draw.bezier((0.4, 0.6), (1.4, 1.2), (2.8, 2.4), (4.6, 3.6), stroke: graph-color + 1pt)
  draw.content((2.45, -0.38), [$Delta x$])
}

#let double-integral-grid(color: white, graph-color: blue, grid-color: gray) = {
  plane-axes(x-min: -0.3, x-max: 5.2, y-min: -0.3, y-max: 3.8, color: color)
  draw.rect((0.7, 0.6), (4.5, 3.0), stroke: graph-color + 1pt)
  for x in (1.45, 2.2, 2.95, 3.7) {
    draw.line((x, 0.6), (x, 3.0), stroke: grid-color + 0.6pt)
  }
  for y in (1.2, 1.8, 2.4) {
    draw.line((0.7, y), (4.5, y), stroke: grid-color + 0.6pt)
  }
  draw.content((2.6, 1.5), [$R_(i j)$])
  draw.content((2.1, 0.25), [$Delta x$])
  draw.content((4.85, 1.45), [$Delta y$])
}

#let area-element-diagram(color: white, graph-color: blue) = {
  plane-axes(x-min: -0.3, x-max: 4.8, y-min: -0.3, y-max: 3.6, color: color)
  draw.rect((1.3, 1.0), (2.8, 2.0), stroke: graph-color + 1pt)
  draw.content((2.05, 1.5), [$d A$])
  draw.content((2.05, 0.68), [$d x$])
  draw.content((3.12, 1.5), [$d y$])
}

#let rectangle-region-abcd(color: white, graph-color: blue) = {
  plane-axes(x-min: -0.3, x-max: 5.2, y-min: -0.3, y-max: 3.8, color: color)
  draw.rect((1.0, 0.8), (4.2, 3.0), stroke: graph-color + 1pt)
  draw.content((1.0, 0.35), [$a$])
  draw.content((4.2, 0.35), [$b$])
  draw.content((0.55, 0.8), [$c$])
  draw.content((0.55, 3.0), [$d$])
  draw.content((2.6, 1.9), [$R=[a,b] times [c,d]$])
}

#let draw-polyline(points, stroke) = {
  for i in range(0, points.len() - 1) {
    draw.line(points.at(i), points.at(i + 1), stroke: stroke)
  }
}

#let fubini-vertical-region(
  top: (),
  bottom: (),
  left: none,
  right: none,
  hatch: (),
  a-x: auto,
  b-x: auto,
  label-pos: none,
  top-label-pos: none,
  bottom-label-pos: none,
  x-min: -0.3,
  x-max: 4.8,
  y-min: -0.3,
  y-max: 3.8,
  a-label: [$a$],
  b-label: [$b$],
  region-label: [$B$],
  top-label: [$g_2(x)$],
  bottom-label: [$g_1(x)$],
  color: white,
  graph-color: blue,
  guide-color: gray,
) = {
  let left-side = if left == none { (bottom.at(0), top.at(0)) } else { left }
  let right-side = if right == none { (bottom.at(bottom.len() - 1), top.at(top.len() - 1)) } else { right }
  let ax = if a-x == auto { left-side.at(0).at(0) } else { a-x }
  let bx = if b-x == auto { right-side.at(0).at(0) } else { b-x }

  plane-axes(x-min: x-min, x-max: x-max, y-min: y-min, y-max: y-max, color: color)
  draw-polyline(top, graph-color + 1pt)
  draw-polyline(bottom, graph-color + 1pt)
  draw-polyline(left-side, graph-color + 1pt)
  draw-polyline(right-side, graph-color + 1pt)

  for segment in hatch {
    draw.line(segment.at(0), segment.at(1), stroke: guide-color + 0.45pt)
  }

  draw.line((ax, 0), (ax, y-max - 0.65), stroke: guide-color + 0.7pt)
  draw.line((bx, 0), (bx, y-max - 0.65), stroke: guide-color + 0.7pt)
  draw.content((ax, -0.35), a-label)
  draw.content((bx, -0.35), b-label)
  if label-pos != none {
    draw.content(label-pos, region-label)
  }
  if top-label-pos != none {
    draw.content(top-label-pos, top-label)
  }
  if bottom-label-pos != none {
    draw.content(bottom-label-pos, bottom-label)
  }
}

#let fubini-horizontal-region(
  left: (),
  right: (),
  top: none,
  bottom: none,
  hatch: (),
  c-y: auto,
  d-y: auto,
  label-pos: none,
  left-label-pos: none,
  right-label-pos: none,
  x-min: -0.3,
  x-max: 5.0,
  y-min: -0.3,
  y-max: 3.8,
  c-label: [$c$],
  d-label: [$d$],
  region-label: [$B$],
  left-label: [$x = h_1(y)$],
  right-label: [$x = h_2(y)$],
  color: white,
  graph-color: blue,
  guide-color: gray,
) = {
  let top-side = if top == false { () } else if top == none { (left.at(left.len() - 1), right.at(0)) } else { top }
  let bottom-side = if bottom == false { () } else if bottom == none { (left.at(0), right.at(right.len() - 1)) } else { bottom }
  let cy = if c-y == auto {
    if bottom-side.len() > 0 { bottom-side.at(0).at(1) } else { none }
  } else {
    c-y
  }
  let dy = if d-y == auto {
    if top-side.len() > 0 { top-side.at(0).at(1) } else { none }
  } else {
    d-y
  }

  plane-axes(x-min: x-min, x-max: x-max, y-min: y-min, y-max: y-max, color: color)
  draw-polyline(left, graph-color + 1pt)
  draw-polyline(right, graph-color + 1pt)
  if top-side.len() > 0 {
    draw-polyline(top-side, graph-color + 1pt)
  }
  if bottom-side.len() > 0 {
    draw-polyline(bottom-side, graph-color + 1pt)
  }

  for segment in hatch {
    draw.line(segment.at(0), segment.at(1), stroke: guide-color + 0.45pt)
  }

  if cy != none {
    draw.line((0, cy), (x-max - 1.15, cy), stroke: guide-color + 0.7pt)
    draw.content((-0.28, cy), c-label)
  }
  if dy != none {
    draw.line((0, dy), (x-max - 1.15, dy), stroke: guide-color + 0.7pt)
    draw.content((-0.28, dy), d-label)
  }
  if label-pos != none {
    draw.content(label-pos, region-label)
  }
  if left-label-pos != none {
    draw.content(left-label-pos, left-label)
  }
  if right-label-pos != none {
    draw.content(right-label-pos, right-label)
  }
}

#let vertical-region-diagram(color: white, graph-color: blue, guide-color: gray) = {
  plane-axes(x-min: -0.3, x-max: 5.0, y-min: -0.3, y-max: 4.0, color: color)
  draw.bezier((0.8, 0.7), (1.7, 0.9), (3.2, 0.7), (4.2, 1.1), stroke: graph-color + 1pt)
  draw.bezier((0.8, 2.4), (1.7, 3.4), (3.2, 3.1), (4.2, 2.6), stroke: graph-color + 1pt)
  draw.line((0.8, 0.7), (0.8, 2.4), stroke: graph-color + 1pt)
  draw.line((4.2, 1.1), (4.2, 2.6), stroke: graph-color + 1pt)
  draw.line((2.6, 0.85), (2.6, 3.05), stroke: guide-color + 0.8pt, mark: (end: ">"))
  draw.content((2.85, 3.1), [$g_2(x)$])
  draw.content((2.85, 0.8), [$g_1(x)$])
}

#let vertical-region-diagram-1(color: white, graph-color: blue, guide-color: gray) = {
  plane-axes(x-min: -0.3, x-max: 4.8, y-min: -0.3, y-max: 3.4, color: color)
  let top = ((1.0, 2.45), (1.35, 2.85), (1.8, 2.7), (2.25, 2.35), (2.7, 2.4), (3.05, 2.75))
  let bottom = ((1.0, 1.35), (1.35, 1.75), (1.8, 1.6), (2.25, 1.25), (2.7, 1.3), (3.05, 1.65))
  for i in range(0, top.len() - 1) {
    draw.line(top.at(i), top.at(i + 1), stroke: graph-color + 1pt)
    draw.line(bottom.at(i), bottom.at(i + 1), stroke: graph-color + 1pt)
  }
  draw.line((1.28, 1.45), (1.58, 2.65), stroke: guide-color + 0.45pt)
  draw.line((1.65, 1.55), (2.0, 2.55), stroke: guide-color + 0.45pt)
  draw.line((2.05, 1.38), (2.42, 2.35), stroke: guide-color + 0.45pt)
  draw.line((1.0, 0), (1.0, 2.7), stroke: guide-color + 0.7pt)
  draw.line((3.05, 0), (3.05, 2.95), stroke: guide-color + 0.7pt)
  draw.content((1.25, -0.35), [$a$])
  draw.content((3.05, -0.35), [$b$])
  draw.content((1.85, 1.95), [$B$])
  draw.content((3.3, 2.7), [$g_2(x)$])
  draw.content((3.3, 1.45), [$g_1(x)$])
}

#let vertical-region-diagram-2(color: white, graph-color: blue, guide-color: gray) = {
  plane-axes(x-min: -0.3, x-max: 4.8, y-min: -0.3, y-max: 3.8, color: color)
  let left = ((1.45, 2.9), (1.05, 2.72), (0.85, 2.35), (0.75, 1.95), (0.82, 1.55), (1.05, 1.2), (1.45, 1.02))
  let top = ((1.45, 2.9), (1.95, 3.05), (2.45, 2.98), (2.9, 2.78))
  let bottom = ((1.45, 1.02), (1.95, 0.82), (2.45, 0.9), (2.9, 1.12))
  for i in range(0, left.len() - 1) {
    draw.line(left.at(i), left.at(i + 1), stroke: graph-color + 1pt)
  }
  for i in range(0, top.len() - 1) {
    draw.line(top.at(i), top.at(i + 1), stroke: graph-color + 1pt)
    draw.line(bottom.at(i), bottom.at(i + 1), stroke: graph-color + 1pt)
  }
  draw.line((2.9, 1.12), (2.9, 2.78), stroke: graph-color + 1pt)
  draw.line((1.05, 1.35), (1.45, 2.65), stroke: guide-color + 0.45pt)
  draw.line((1.45, 1.05), (1.95, 2.9), stroke: guide-color + 0.45pt)
  draw.line((1.95, 0.92), (2.45, 2.85), stroke: guide-color + 0.45pt)
  draw.line((2.42, 0.98), (2.75, 2.65), stroke: guide-color + 0.45pt)
  draw.line((1.25, 0), (1.25, 3.15), stroke: guide-color + 0.7pt)
  draw.line((2.9, 0), (2.9, 3.15), stroke: guide-color + 0.7pt)
  draw.content((1.25, -0.35), [$a$])
  draw.content((2.9, -0.35), [$b$])
  draw.content((1.8, 1.85), [$B$])
  draw.content((3.18, 2.8), [$y = g_2(x)$])
  draw.content((3.18, 1.1), [$y = g_1(x)$])
}

#let vertical-region-diagram-3(color: white, graph-color: blue, guide-color: gray) = {
  plane-axes(x-min: -0.3, x-max: 4.8, y-min: -0.3, y-max: 3.7, color: color)
  let top = ((1.0, 1.7), (1.35, 1.55), (1.65, 2.2), (2.05, 2.55), (2.45, 2.4), (2.95, 2.0), (3.25, 2.05))
  let bottom = ((1.0, 1.45), (1.35, 1.05), (1.8, 0.9), (2.3, 0.9), (2.75, 1.05), (3.25, 1.35))
  for i in range(0, top.len() - 1) {
    draw.line(top.at(i), top.at(i + 1), stroke: graph-color + 1pt)
  }
  for i in range(0, bottom.len() - 1) {
    draw.line(bottom.at(i), bottom.at(i + 1), stroke: graph-color + 1pt)
  }
  draw.line((1.0, 1.45), (1.0, 1.7), stroke: graph-color + 1pt)
  draw.line((3.25, 1.35), (3.25, 2.05), stroke: graph-color + 1pt)
  draw.line((1.15, 1.4), (1.55, 1.95), stroke: guide-color + 0.45pt)
  draw.line((1.55, 1.05), (2.0, 2.35), stroke: guide-color + 0.45pt)
  draw.line((2.0, 0.95), (2.45, 2.45), stroke: guide-color + 0.45pt)
  draw.line((2.45, 1.0), (2.9, 2.15), stroke: guide-color + 0.45pt)
  draw.line((1.0, 0), (1.0, 2.25), stroke: guide-color + 0.7pt)
  draw.line((3.25, 0), (3.25, 2.35), stroke: guide-color + 0.7pt)
  draw.content((1.0, -0.35), [$a$])
  draw.content((3.25, -0.35), [$b$])
  draw.content((2.05, 1.55), [$B$])
  draw.content((3.55, 2.1), [$g_2(x)$])
  draw.content((3.55, 1.25), [$g_1(x)$])
}

#let horizontal-region-diagram(color: white, graph-color: blue, guide-color: gray) = {
  plane-axes(x-min: -0.3, x-max: 5.0, y-min: -0.3, y-max: 4.0, color: color)
  draw.bezier((1.1, 0.7), (0.7, 1.4), (0.9, 2.6), (1.4, 3.3), stroke: graph-color + 1pt)
  draw.bezier((3.7, 0.7), (4.6, 1.5), (4.3, 2.7), (3.5, 3.3), stroke: graph-color + 1pt)
  draw.line((1.1, 0.7), (3.7, 0.7), stroke: graph-color + 1pt)
  draw.line((1.4, 3.3), (3.5, 3.3), stroke: graph-color + 1pt)
  draw.line((1.0, 2.0), (4.15, 2.0), stroke: guide-color + 0.8pt, mark: (end: ">"))
  draw.content((0.55, 2.0), [$h_1(y)$])
  draw.content((4.35, 2.0), [$h_2(y)$])
}

#let horizontal-region-diagram-1(color: white, graph-color: blue, guide-color: gray) = {
  plane-axes(x-min: -0.3, x-max: 5.0, y-min: -0.3, y-max: 3.8, color: color)
  let left = ((1.35, 0.75), (1.12, 1.15), (1.32, 1.55), (1.08, 1.95), (1.28, 2.35), (1.12, 2.75), (1.38, 3.1))
  let right = ((3.15, 0.75), (2.92, 1.15), (3.12, 1.55), (2.88, 1.95), (3.08, 2.35), (2.92, 2.75), (3.18, 3.1))
  let top = ((1.38, 3.1), (1.85, 3.25), (2.45, 3.25), (3.18, 3.1))
  let bottom = ((1.35, 0.75), (1.9, 0.62), (2.45, 0.62), (3.15, 0.75))
  for i in range(0, left.len() - 1) {
    draw.line(left.at(i), left.at(i + 1), stroke: graph-color + 1pt)
    draw.line(right.at(i), right.at(i + 1), stroke: graph-color + 1pt)
  }
  for i in range(0, top.len() - 1) {
    draw.line(top.at(i), top.at(i + 1), stroke: graph-color + 1pt)
    draw.line(bottom.at(i), bottom.at(i + 1), stroke: graph-color + 1pt)
  }
  draw.line((1.55, 0.9), (2.0, 2.95), stroke: guide-color + 0.45pt)
  draw.line((2.0, 0.72), (2.45, 3.05), stroke: guide-color + 0.45pt)
  draw.line((2.45, 0.75), (2.9, 2.9), stroke: guide-color + 0.45pt)
  draw.line((0, 1.9), (3.05, 1.9), stroke: guide-color + 0.7pt)
  draw.content((2.05, 1.9), [$B$])
  draw.content((3.45, 2.75), [$x = h_1(y)$])
  draw.content((3.45, 1.1), [$x = h_2(y)$])
}

#let horizontal-region-diagram-2(color: white, graph-color: blue, guide-color: gray) = {
  plane-axes(x-min: -0.3, x-max: 5.0, y-min: -0.3, y-max: 3.8, color: color)
  let left = ((1.45, 0.85), (1.05, 1.25), (0.92, 1.8), (1.05, 2.35), (1.55, 2.95))
  let top = ((1.55, 2.95), (2.05, 3.15), (2.7, 3.15), (3.25, 2.95))
  let right = ((3.25, 2.95), (3.75, 2.35), (3.88, 1.8), (3.75, 1.25), (3.35, 0.85))
  let bottom = ((1.45, 0.85), (2.0, 0.72), (2.75, 0.72), (3.35, 0.85))
  for i in range(0, left.len() - 1) {
    draw.line(left.at(i), left.at(i + 1), stroke: graph-color + 1pt)
    draw.line(right.at(i), right.at(i + 1), stroke: graph-color + 1pt)
  }
  for i in range(0, top.len() - 1) {
    draw.line(top.at(i), top.at(i + 1), stroke: graph-color + 1pt)
  }
  for i in range(0, bottom.len() - 1) {
    draw.line(bottom.at(i), bottom.at(i + 1), stroke: graph-color + 1pt)
  }
  draw.line((1.45, 0.95), (1.95, 2.75), stroke: guide-color + 0.45pt)
  draw.line((2.0, 0.78), (2.55, 3.0), stroke: guide-color + 0.45pt)
  draw.line((2.55, 0.78), (3.15, 2.85), stroke: guide-color + 0.45pt)
  draw.line((0, 0.85), (3.35, 0.85), stroke: guide-color + 0.7pt)
  draw.line((0, 2.95), (3.25, 2.95), stroke: guide-color + 0.7pt)
  draw.content((-0.28, 0.85), [$c$])
  draw.content((-0.28, 2.95), [$d$])
  draw.content((2.45, 1.75), [$B$])
  draw.content((3.85, 2.75), [$x = h_1(y)$])
  draw.content((3.85, 1.0), [$x = h_2(y)$])
}

#let three-tension-forces(color: white) = {
  force-arrow((0, 0), (0, -1.6), [$arrow(T)_1$], (0.25, -1.35), color: color)
  force-arrow((0, 0), (-1.7, 1.0), [$arrow(T)_2$], (-2.0, 1.15), color: color)
  force-arrow((0, 0), (1.7, 1.0), [$arrow(T)_3$], (1.9, 1.15), color: color)
  draw.arc((0, 0), radius: 0.65, start: 0deg, delta: 60deg, stroke: color)
  draw.content((0.75, 0.35), [$60 degree$])
}

#let local-maximum-sketch(color: white, graph-color: blue, guide-color: gray) = {
  draw.line((0, 0), (4.5, 0), stroke: color, mark: (end: ">"))
  draw.line((0, 0), (-1.2, -0.8), stroke: color, mark: (end: ">"))
  draw.line((0, 0), (0, 3.0), stroke: color, mark: (end: ">"))
  draw.content((4.75, 0), [$x$])
  draw.content((-1.45, -0.95), [$y$])
  draw.content((0, 3.25), [$z$])
  draw.bezier((0.8, 0.45), (1.5, 2.2), (2.3, 2.75), (3.2, 0.45), stroke: graph-color + 1pt)
  draw.bezier((0.9, 0.3), (1.8, -0.1), (2.8, -0.1), (3.8, 0.3), stroke: guide-color + 0.7pt)
  draw.circle((2.25, 2.15), radius: 0.07, fill: color, stroke: color)
  draw.content((2.45, 2.25), [$"max"$])
  draw.content((2.25, -0.35), [$"disco"$])
}

#let local-minimum-sketch(color: white, graph-color: blue, guide-color: gray) = {
  draw.line((0, 0), (4.5, 0), stroke: color, mark: (end: ">"))
  draw.line((0, 0), (-1.2, -0.8), stroke: color, mark: (end: ">"))
  draw.line((0, -1.1), (0, 3.0), stroke: color, mark: (end: ">"))
  draw.content((4.75, 0), [$x$])
  draw.content((-1.45, -0.95), [$y$])
  draw.content((0, 3.25), [$z$])
  draw.bezier((0.8, 2.25), (1.5, 0.55), (2.3, 0.25), (3.2, 2.25), stroke: graph-color + 1pt)
  draw.bezier((0.9, 0.3), (1.8, -0.1), (2.8, -0.1), (3.8, 0.3), stroke: guide-color + 0.7pt)
  draw.circle((2.1, 0.75), radius: 0.07, fill: color, stroke: color)
  draw.content((2.35, 0.75), [$"min"$])
  draw.content((2.25, -0.35), [$"disco"$])
}
