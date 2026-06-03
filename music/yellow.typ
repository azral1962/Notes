#import "@preview/tieflied:0.2.1": annotation, author, bridge, chorus, set-page-breaking, song, songbook, verse

#let cavetown = author(
  "Cavetown",
  color: color.hsv(178.6deg, 16.86%, 100%),
)

#songbook(
  title: "Buku Lagu",
  songbook-author: "Armein Z. R. langi",
  title-page: true,
  settings: (
    show-annotations: true,
    page-per-song: true,
    start-right: false,
  ),
  [
    #song(author: "Coldplay", title: "Yellow", [
      #verse[
        Look at the stars\
        Look how they shine for you\
        And everything you do\
        Yeah, they were all yellow
      ]
      #verse[
        I came along\
        I wrote a song for you\
        And all the things you do\
        And it was called yellow
      ]
      #verse[
        So, then I took my turn\
        Oh, what a thing to have done\
        And it was all yellow
      ]
      #chorus[
        your skin, oh yeah, your skin, and bones\
        (Ooh) turn into something beautiful\
        (Ah) and you know, you know I love you so\
        You know I love you so
      ]
      #verse[
        I swam across\
        I jumped across for you\
        Oh, what a thing to do\
        'Cause you were all yellow
      ]
      #verse[
        I drew a line\
        I drew a line for you\
        Oh, what a thing to do\
        And it was all yellow
      ]
      #chorus[
        and your skin, oh yeah, your skin, and bones\
        (Ooh) turn into something beautiful\
        (Ah) and you know, for you, I'd bleed myself dry\
        For you, I'd bleed myself dry
      ]
      #bridge [
        It's true\
        Look how they shine for you\
        Look how they shine for you\
        Look how they shine for-
      ]
      #bridge [
        Look how they shine for you\
        Look how they shine for you\
        Look how they shine
      ]
      #verse[
        Look at the stars\
        Look how they shine for you\
        And all the things that you do
      ]

    ])
  ],
)
