#import "@preview/bamdone-ieeeconf:0.1.3": ieee

#show: ieee.with(
  title: [Preparation of Papers for IEEE Sponsored Conferences & Symposia],
  abstract: [
    This electronic document is a live template. The various components of your paper [title, text, heads, etc.] are already defined on the style sheet, as illustrated by the portions given in this document.
  ],
authors: (
    (
      given: "Albert",
      surname: "Author",
      email: [albert.author],
      affiliation: 1
    ),
    (
      given: "Bernard D.",
      surname: "Researcher",
      email: [b.d.researcher],
      affiliation: 2
    )
  ),
  affiliations: (
    (
      name: [Faculty of Electrical Engineering, Mathematics and Computer Science, University of Twente],
      address: [7500 AE Enchede, The Netherlands],
      email-suffix: [papercept.net],
    ),
    (
      name: [Department of Electrical Engineering, Wright State University],
      address: [Dayton, OH 45435, USA],
      email-suffix: [ieee.org]
    ),
  ),
  index-terms: (),
  bibliography: bibliography("refs.bib"),
  draft: false,               // Adds the draft markers on the footer and header
  paper-size: "us-letter",
)

// Your content goes below.


#include("isi.typ")
