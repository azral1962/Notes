#show: book.with(
$if(title)$
  title: "$title$",
$endif$
$if(author)$
  author: "$author$",
$endif$
$if(paper-size)$
  paper-size: "$paper-size$",
$endif$
$if(dedication)$
  dedication: [$dedication$],
$endif$
$if(publishing-info)$
  publishing-info: [$publishing-info$],
$endif$
)
