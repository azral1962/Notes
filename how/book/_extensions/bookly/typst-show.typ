
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
$if(title)$
  title: "$title$",
$endif$
$if(author)$
  author: "$author$",
$endif$
$if(lang)$
  lang: "$lang$",
$endif$
$if(theme)$
  theme: $theme$,
$else$ 
  theme: classic,
$endif$
$if(tufte)$
  tufte: $tufte$,
$else$  
  tufte: false,
$endif$

  title-page: book-title-page(
    $if(subtitle)$subtitle: "$subtitle$",$else$subtitle: "subtitle",$endif$
    $if(seri)$series: "$seri$",$else$series: "series",$endif$
    $if(institusi)$institution: "$institusi$",$else$institution: "institution",$endif$
  ),
  config-options: (
    $if(buka-kanan)$open-right: $buka-kanan$,$else$open-right: true, $endif$
    $if(margin-alternatif)$alt-margins: $margin-alternatif$,$else$alt-margins: true,$endif$
  ),
)

$if(papersize)$
  paper: "$papersize$",
$endif$
$if(mainfont)$
  font: ("$mainfont$",),
$elseif(brand.typography.base.family)$
  font: $brand.typography.base.family$,
$endif$
$if(fontsize)$
  fontsize: $fontsize$,
$elseif(brand.typography.base.size)$
  fontsize: $brand.typography.base.size$,
$endif$