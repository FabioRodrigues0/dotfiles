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
