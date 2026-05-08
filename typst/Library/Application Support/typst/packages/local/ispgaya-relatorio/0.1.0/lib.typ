// ════════════════════════════════════════════════════════════════════════════
// ispgaya-relatorio — Template académico ISPGAYA
// @local/ispgaya-relatorio:0.1.0
//
// Guião de Redação e Formatação de Trabalhos Académicos do ISPGAYA
// 2.ª edição, fevereiro 2025
//
// Margens : Top 2,54 | Esq 3,81 | Dir 2,54 | Inf 2,54  (cm)
// Fonte   : Times New Roman 12pt
// Espaç.  : 1,5 linhas | Parágrafo: 1,25cm indent
// Págs.   : romana (índice) → árabe (corpo), canto inf. direito
//
// Exporta:
//   relatorio(...)      — função de show rule principal
//   secao_sem_numero(t) — heading sem numeração (Introdução / Conclusão)
//   nota_fonte(body)    — nota de fonte em figuras e tabelas
// ════════════════════════════════════════════════════════════════════════════

#let INSTITUICAO = "Instituto Superior Politécnico Gaya"
#let CURSO = "Engenharia Informática"
#let LOGO_PATH = "logo_faculdade.png"

// ── Heading sem numeração (Introdução / Conclusão — guião 3.1) ───────────────
#let secao_sem_numero(titulo) = {
  pagebreak(weak: true)
  v(1em)
  text(size: 14pt, weight: "bold")[#titulo]
  v(0.5em)
}

// ── Nota de fonte para figuras e tabelas (guião 3.2.4) ───────────────────────
// Uso: #nota_fonte[Retirado de Autor (2024, p. 10).]
#let nota_fonte(body) = {
  v(0.2em)
  text(size: 10pt, style: "italic")[Nota. #body]
}

// ── Função principal ─────────────────────────────────────────────────────────
#let relatorio(
  titulo: "",
  subtitulo: "",
  autores: (),
  numeros: (),
  disciplina: "",
  orientador: "",
  data: "",
  body,
) = {

  set document(title: titulo, author: autores)

  // Página base
  set page(
    paper: "a4",
    margin: (top: 2.54cm, left: 3.81cm, right: 2.54cm, bottom: 2.54cm),
  )

  // Tipografia — Times New Roman 12pt (guião 3.1)
  set text(font: "Times New Roman", size: 12pt, lang: "pt")

  // Parágrafos — 1,5 linhas, indent 1,25cm (guião 3.1)
  set par(
    justify:           true,
    leading:           0.65em,
    spacing:           1.2em,
    first-line-indent: 1.25cm,
  )

  // Headings numerados (guião 3.1 — exceto Introdução/Conclusão)
  set heading(numbering: "1.1.")

  show heading.where(level: 1): it => {
    pagebreak(weak: true)
    v(1em)
    text(size: 14pt, weight: "bold", it)
    v(0.5em)
  }
  show heading.where(level: 2): it => {
    v(0.8em)
    text(size: 13pt, weight: "bold", it)
    v(0.4em)
  }
  show heading.where(level: 3): it => {
    v(0.5em)
    text(size: 12pt, weight: "bold", it)
    v(0.25em)
  }

  // Figuras — número + título em cima, alinhado à esquerda, 10pt itálico
  set figure(numbering: "1", gap: 0.5em)
  show figure.caption: it => {
    set text(size: 10pt, style: "italic")
    align(left)[
      #it.supplement #it.counter.display(it.numbering)
      #linebreak()
      #it.body
    ]
  }

  // Código
  show raw.where(block: true): block.with(
    fill: luma(245), inset: (x: 1em, y: 0.75em), radius: 4pt, width: 100%,
  )
  show raw.where(block: false): box.with(
    fill: luma(245), inset: (x: 0.3em, y: 0.15em), radius: 3pt,
  )

  // ── CAPA ─────────────────────────────────────────────────────────────────
  page(
    numbering: none,
    margin: (top: 2.54cm, bottom: 2.54cm, left: 2.54cm, right: 2.54cm),
  )[
    #align(center)[
      #v(2cm)
      #if LOGO_PATH != "" {
        image(LOGO_PATH, width: 30%)
        v(1.5cm)
      } else { v(1.5cm) }

      #text(size: 18pt, weight: "bold")[#INSTITUICAO]
      #v(0.3cm)
      #text(size: 13pt)[#CURSO]
      #v(2cm)

      #text(size: 22pt, weight: "bold")[#titulo]
      #if subtitulo != "" { v(0.3cm); text(size: 14pt)[#subtitulo] }
      #v(1cm)

      #for (i, autor) in autores.enumerate() {
        text(size: 13pt)[#autor]
        if i < numeros.len() {
          text(size: 11pt, fill: luma(100))[ — n.º #numeros.at(i)]
        }
        linebreak()
      }
      #v(0.8cm)
      #if disciplina != "" { text(size: 12pt)[#disciplina]; linebreak() }
      #if orientador != "" {
        v(0.3cm)
        text(size: 11pt, fill: luma(80))[Orientado por #orientador]
      }
      #v(1fr)
      #text(size: 12pt)[#data]
      #v(0.5cm)
    ]
  ]

  // ── ÍNDICE (numeração romana — guião 3.2.4) ───────────────────────────────
  set page(numbering: "i", number-align: bottom + right)
  counter(page).update(1)
  outline(title: [Índice], depth: 3, indent: 1.5em)

  // Reset do counter de headings — o outline incrementa-o internamente
  counter(heading).update(1)

  // ── CORPO (numeração árabe — guião 3.2.4) ────────────────────────────────
  pagebreak()
  set page(
    numbering: "1",
    number-align: bottom + right,
    header: context {
      if here().page() > 1 [
        #grid(
          columns: (1fr, 1fr),
          align(left,  text(size: 9pt, fill: luma(120))[#titulo]),
          align(right, text(size: 9pt, fill: luma(120))[#disciplina]),
        )
        #line(length: 100%, stroke: 0.4pt + luma(200))
        #v(-0.3em)
      ]
    },
  )
  counter(page).update(1)

  body
}
