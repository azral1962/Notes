#import "@preview/bookly:2.1.2": *


#let config-colors = (
  primary: rgb("#1d90d0"),
  secondary: rgb("#dddddd").darken(15%),
)
// IN HEADER!!!


#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "iso-b5",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)


// Typst custom formats typically consist of a 'typst-template.typ' (which is
// the source code for a typst template) and a 'typst-show.typ' which calls the
// template's function (forwarding Pandoc metadata values as required)
//
// This is an example 'typst-show.typ' file (based on the default template
// that ships with Quarto). It calls the typst function named 'article' which
// is defined in the 'typst-template.typ' file.
//
// If you are creating or packaging a custom typst template you will likely
// want to replace this file and 'typst-template.typ' entirely. You can find
// documentation on creating typst templates here and some examples here:
//   - https://typst.app/docs/tutorial/making-a-template/
//   - https://github.com/typst/templates
#show: bookly.with(
  title: "How to do things with Typst",
  author: "Armein Z. R. Langi",
  lang: "id",
  theme: "fancy",
  tufte: true,

  title-page: book-title-page(
    subtitle: "A Typst book",
    series: "buku serial",
    institution: "Institut Teknologi Bandung",
  ),
  config-options: (
    open-right: true,
    alt-margins: true,
  ),
)
// IN BEFORE !!!
// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Preface]
<preface>
This is a Quarto book.

To learn more about Quarto books visit #link("https://quarto.org/docs/books").

= Introduction
<introduction>
This is a book created from markdown and executable code.

See #cite(<knuth84>, form: "prose") for additional discussion of literate programming.

= Summary
<summary>
In summary, this book has no content whatsoever.

#heading(level: 1, numbering: none)[References]
<references>
#block[
] <refs>



#bibliography("references.bib")
