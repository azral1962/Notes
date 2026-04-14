// IN BEFORE !!!
#set text(
  font: "New Computer Modern", // Font family name
  size: 12pt, // Font size
)

#show: front-matter


#show: main-matter
#states.isfrontmatter.update(true)

#tableofcontents

#listoffigures

#listoftables

