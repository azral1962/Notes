#import "@preview/bookly:2.1.2": *
// #import "../src/bookly.typ": *

#let config-colors = (
  primary: rgb("#1d90d0"),
  secondary: rgb("#dddddd").darken(15%),
)

#show: bookly.with(
  author: "Author Name",
  fonts: (
    body: "Lato",
    math: "Lete Sans Math",
  ),
  // theme: custom,
  // theme: classic,
  // theme: fancy,
  // theme: modern,
  // theme: orly,
  // theme: pretty,
  // tufte: true,
  lang: "id",
  // colors: config-colors,
  title-page: book-title-page(
    series: "Typst book series",
    institution: "Typst community",
    logo: image("logo.png", width: 10%),
    cover: image("cover.png", width: 45%),
  ),
  config-options: (
    open-right: true,
    // alt-margins: true,
  ),
)
