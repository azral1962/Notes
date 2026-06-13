// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}



// Import from upstream charged-ieee package on Typst Universe
// https://typst.app/universe/package/charged-ieee
#import "@preview/charged-ieee:0.1.4": ieee
#show: ieee.with(
  title: "Value Co-Creation Modeling for Mission-Oriented Sustainable Service Ecosystems: A Multi-Stakeholder Recommendation Framework for Campus Food Services",
  abstract: [Mission-oriented sustainable ecosystems require organizations to coordinate multiple stakeholders whose objectives are interdependent but not fully aligned. This paper proposes a #strong[value co-creation modeling framework] for designing and improving sustainable service ecosystems through a #strong[Multi-Stakeholder Recommendation System (MSRS)] embedded in a decision-support architecture. The framework is developed from an engineering management perspective, with emphasis on system design, stakeholder coordination, operational feasibility, and performance improvement.

The study applies the framework to #strong[healthy, tasty, and affordable campus food services], a setting in which consumers, canteens, food providers, suppliers, researchers, and university administrators jointly shape service outcomes. The proposed model integrates three elements: (1) a stakeholder ecosystem model, (2) a food-flow model tracing the transformation of raw ingredients into ready-to-consume meals and waste streams, and (3) a decision-support system that uses MSRS logic to coordinate menu planning, procurement, pricing, production, and personalized recommendations. In this architecture, the MSRS is not treated solely as a consumer personalization tool; rather, it functions as a coordination mechanism for balancing taste, health, affordability, operational efficiency, supplier stability, and sustainability.

This paper contributes to engineering management in three ways. First, it formalizes value co-creation as a design problem in mission-oriented sustainable ecosystems. Second, it extends recommendation systems from user-centric optimization to multi-stakeholder coordination. Third, it provides a simulation-ready framework for evaluating ecosystem performance using multidimensional measures such as healthy meal uptake, taste satisfaction, price accessibility, waste reduction, and sustainability. The framework offers a transferable foundation for managing sustainable service ecosystems in food and other industries where digital intelligence can improve both stakeholder value and system-level performance.

],
  authors: (
    (
      name: "First Author",
      department: [STEI],
      organization: [ITB],
      location: [Bandung, Indonesia],
      email: "author1\@university.edu",
    ),
    (
      name: "Second Author",
      department: [STEI],
      organization: [ITB],
      location: [Bandung, Indonesia],
      email: "author2\@university.edu",
    ),
    (
      name: "Third Author",
      department: [STEI],
      organization: [ITB],
      location: [Bandung, Indonesia],
      email: "author3\@university.edu",
    ),
  ),
  index-terms: ([engineering management], [mission-oriented innovation], [sustainable service ecosystem], [value co-creation], [multi-stakeholder recommendation system], [decision support system], [service innovation], [campus food services], [affordability], [sustainability]),
  bibliography: bibliography("references.bib"),
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)


= Introduction
<introduction>
University campuses provide a revealing context for engineering management because they operate as service ecosystems in which multiple actors must coordinate around shared but partially conflicting objectives. In food services, students and staff seek meals that are healthy, tasty, convenient, and affordable; canteens seek operational feasibility and waste reduction; suppliers seek stable and predictable demand; and university administrators seek alignment with broader missions of sustainability, wellbeing, and inclusion. Managing such ecosystems is difficult because value is not created by any single actor in isolation, but co-created through interdependent decisions across sourcing, production, pricing, consumption, and governance. This paper argues that mission-oriented sustainable service ecosystems can be better designed when value co-creation is modeled explicitly and supported by digital coordination mechanisms such as multi-stakeholder recommendation systems. Using the case of campus food services, we develop a framework that integrates stakeholder utilities, food flows, and decision-support logic to show how engineering management can move from optimizing isolated functions to orchestrating ecosystem-level performance.

Despite this importance, campus food environments often remain characterized by unhealthy default options, limited dietary personalization, operational inefficiencies, price sensitivity, and food waste. Existing food recommender systems offer useful personalization tools, but most are designed to optimize outcomes for a single stakeholder, usually the consumer. In contrast, a campus food system involves multiple stakeholders whose interests are interdependent: consumers seek healthy, affordable, and appealing meals; canteens seek feasible production and reduced waste; suppliers seek stable demand; researchers seek measurable intervention settings; and administrators seek alignment with institutional health and sustainability goals.

This paper addresses that gap by developing a #strong[systematic literature review and conceptual framework] for a #strong[multi-stakeholder healthy-food ecosystem] for university campuses. The central argument is that food recommendation in this setting should be understood as a coordination mechanism linking choice, operations, procurement, sustainability, and governance rather than as a simple user-only prediction task.

= Review Methodology
<review-methodology>
== Review objective
<review-objective>
The review aimed to identify and synthesize research relevant to a #strong[healthy-food ecosystem for university campuses using multi-stakeholder recommendation systems]. Because this exact topic is still emerging, the review used an interdisciplinary search strategy spanning four linked domains:

+ campus food environments,
+ food and healthy-food recommender systems,
+ multi-stakeholder recommendation and fairness,
+ sustainability and food-service operations.

== Search strategy
<search-strategy>
A rapid systematic review logic was applied using targeted scholarly web searching across the four domains above. Search terms included combinations of the following concepts:

- multi-stakeholder recommendation,
- food recommender systems,
- healthy food recommendation,
- campus food environment,
- university food environment,
- university restaurants sustainability,
- food waste in food services.

Priority was given to review papers, foundational conceptual papers, technical studies with clear relevance, and implementation-oriented studies.

== Inclusion criteria
<inclusion-criteria>
Studies were included if they contributed directly to at least one of the following:

+ university or campus food environments,
+ food or healthy-food recommender systems,
+ multi-stakeholder recommendation, multi-sided fairness, or multi-objective recommendation,
+ sustainability, food-service operations, or waste reduction in institutional dining.

== Exclusion criteria
<exclusion-criteria>
Studies were excluded if they:

- were unrelated to food, recommendation, or institutional dining,
- were too general to inform the proposed framework,
- or did not contribute meaningful conceptual, empirical, or methodological insight.

== Screening and selection logic
<screening-and-selection-logic>
Screening followed a staged logic. First, potentially relevant studies were identified across the four domains. Second, titles and abstracts or result snippets were screened for conceptual relevance. Third, full-text or source-level pages were assessed for eligibility. Studies were retained if they offered direct evidence on campus food behavior or institutional food systems, technical or conceptual foundations for healthy-food recommendation, theoretical grounding for multi-stakeholder recommendation, or sustainability and operational insights relevant to food-service coordination.

= PRISMA-Style Flow of Study Selection
<prisma-style-flow-of-study-selection>
This review followed a rapid systematic literature review approach across four related domains: campus food environments, food and healthy-food recommender systems, multi-stakeholder recommendation and fairness, and sustainability or food-service operations. Because the topic remains emergent and interdisciplinary, the review used a PRISMA-style flow logic rather than a full database-exhaustive PRISMA 2020 procedure.

#block[

#block[
#box(image("healthy_food_ecosystem_slr_paper_files/figure-typst/mermaid-figure-1.png", height: 13.31in, width: 7.72in))

]

]
#strong[Figure 1. PRISMA-style flow of study selection.] Records were identified through targeted scholarly searching across four domains: campus food environments, food recommender systems, multi-stakeholder recommendation, and sustainability or food-service operations. After screening and eligibility assessment, 20 key studies were included in the final thematic synthesis.

= Descriptive Overview of the Literature
<descriptive-overview-of-the-literature>
== Campus food environment research
<campus-food-environment-research>
The campus food environment literature shows that university food settings significantly affect dietary behavior through availability, affordability, convenience, social context, and environmental design @roy2015tertiary@deliens2014determinants@caruso2025campus. This stream establishes the university as a legitimate unit of intervention and supports the view that food choice is shaped by institutional conditions rather than personal preference alone.

== Food and healthy-food recommender systems
<food-and-healthy-food-recommender-systems>
The food recommender systems literature shows that food recommendation is now a well-developed subfield @bondevik2024@tran2018healthy@trattner2017food. Common methods include content-based recommendation, collaborative filtering, hybrid models, and machine-learning approaches. However, most systems remain strongly user-centric even when they include health-aware logic.

== Multi-stakeholder recommendation and fairness
<multi-stakeholder-recommendation-and-fairness>
The multi-stakeholder recommendation literature provides the strongest theoretical foundation for the proposed framework @zheng2017msr@abdollahpouri2019fairness@wu2021multifr. This stream argues that recommendation environments often involve several affected parties and that recommendation quality should therefore be evaluated across multiple utilities rather than only end-user satisfaction.

== Sustainability and food-service operations
<sustainability-and-food-service-operations>
The sustainability and institutional food-service literature emphasizes food waste, restaurant sustainability, and operational coordination @peixoto2026sustainability@guimaraes2024waste. This stream is especially relevant for canteen planning, procurement, and waste reduction, although it is still only weakly connected to healthy-food recommender system design.

= Thematic Synthesis of the Literature
<thematic-synthesis-of-the-literature>
The reviewed literature can be synthesized into four interrelated streams: #strong[campus food environments], #strong[food and healthy-food recommender systems], #strong[multi-stakeholder recommendation], and #strong[sustainability and food-service operations]. Taken together, these streams strongly support the relevance of the proposed topic, but they also show that the field remains fragmented and that an integrated university-campus framework is still underdeveloped @bondevik2024@caruso2025campus@zheng2017msr@peixoto2026sustainability.

== 1. Campus food environments as intervention settings
<campus-food-environments-as-intervention-settings>
A consistent finding across campus food studies is that university food environments shape dietary behavior through factors such as availability, affordability, convenience, time pressure, and social context @roy2015tertiary@deliens2014determinants@caruso2025campus. This means that healthy eating on campus cannot be reduced to individual preference alone. Any recommendation framework intended for university campuses must therefore be embedded in the actual food environment rather than designed as an isolated personalization tool.

== 2. Food recommender systems are mature, but mainly user-centric
<food-recommender-systems-are-mature-but-mainly-user-centric>
The food recommender systems literature is now sufficiently mature to support domain-specific design choices @bondevik2024@tran2018healthy@trattner2017food. However, most existing systems remain centered on the individual user. Even when they incorporate health-aware logic, they usually optimize for some combination of user preference, dietary fit, and nutritional value, while paying limited attention to food-service feasibility, supplier constraints, institutional objectives, or environmental outcomes.

== 3. Multi-stakeholder recommendation offers the strongest theoretical foundation
<multi-stakeholder-recommendation-offers-the-strongest-theoretical-foundation>
The multi-stakeholder recommendation literature provides the clearest conceptual basis for the proposed healthy-food ecosystem @zheng2017msr@abdollahpouri2019fairness@wu2021multifr. This literature is highly relevant because campus food systems are inherently multi-actor environments. Consumers seek taste, convenience, affordability, and health; canteens seek manageable production and waste reduction; suppliers seek predictable demand; and administrators may prioritize sustainability and wellbeing.

== 4. Sustainability and food-service research remain insufficiently integrated with recommendation
<sustainability-and-food-service-research-remain-insufficiently-integrated-with-recommendation>
The sustainability and food-service literature adds an important operational perspective @peixoto2026sustainability@guimaraes2024waste. Research in this stream still focuses heavily on waste reduction, especially post-distribution and plate waste. While this is important, the literature provides weaker integration between sustainability metrics, nutritional goals, and recommendation-system design.

== 5. Explainability, trust, and real-world deployment are emerging priorities
<explainability-trust-and-real-world-deployment-are-emerging-priorities>
Newer implementation-oriented studies indicate that healthy-food recommendation is moving beyond technical prototypes toward real-life settings @workplace2025explanation@wang2024hypergraph@rostami2024group. This has direct implications for campus adoption. A university healthy-food ecosystem would likely require not only accurate recommendation, but also interpretable suggestions, stakeholder buy-in, and policy legitimacy.

== 6. Overall synthesis and gap
<overall-synthesis-and-gap>
Across the reviewed streams, the literature supports three major conclusions @bondevik2024@caruso2025campus@zheng2017msr@peixoto2026sustainability. First, the campus is a valid and influential food environment. Second, healthy-food recommendation is technically feasible and increasingly sophisticated. Third, multi-stakeholder recommendation provides an appropriate framework for balancing competing interests. What remains missing is an integrated model that combines these insights into a single university-campus food ecosystem connecting consumers, canteens, providers, suppliers, researchers, and administrators.

= Evidence Map: 20 Key Papers
<evidence-map-20-key-papers>
#table(
  columns: (14.29%, 14.29%, 14.29%, 14.29%, 14.29%, 14.29%, 14.29%),
  align: (auto,auto,auto,auto,auto,auto,auto,),
  table.header([\#], [Paper], [Stream], [Aim], [Method], [Main finding], [Why it matters],),
  table.hline(),
  [1], [Bondevik et al.~(2024), #emph[A systematic review on food recommender systems]], [Food RS], [Review the food recommender field], [Systematic review], [Food recommenders are mature but fragmented across methods and goals], [High-level overview of food RS],
  [2], [Tran et al.~(2018), #emph[An overview of recommender systems in the healthy food domain]], [Healthy food RS], [Survey healthy-food recommenders], [Technical review], [Healthy-food RS must balance preference, nutrition, and behavior change], [Foundation for healthy recommendation logic],
  [3], [Trattner & Elsweiler (2017), #emph[Food Recommender Systems: Important Contributions, Challenges and Future Research Directions]], [Food RS], [Summarize contributions and challenges], [Scholarly survey], [Food RS differ from generic RS due to health and context], [Seminal conceptual framing],
  [4], [Ge et al.~(2015), #emph[Health-aware Food Recommender System]], [Healthy food RS], [Introduce a health-aware recommender], [Conference system paper], [Health can be embedded in recommendation logic], [Early nutrition-aware system],
  [5], [Rostami et al.~(2024), #emph[A novel healthy food recommendation to user groups…]], [Healthy food RS], [Move from individual to group recommendation], [Model + experiments], [Group recommendation is feasible in food contexts], [Relevant for shared dining settings],
  [6], [Wang et al.~(2024), #emph[Improving healthy food recommender systems through heterogeneous hypergraph learning]], [Healthy food RS], [Improve recommendation accuracy], [ML model], [Richer user-food-ingredient modeling improves personalization], [Useful for technical engine design],
  [7], [Workplace explanation study (2025)], [Explainability], [Study explanations in deployment], [User-centered deployment study], [Explanations improve understanding and control], [Relevant for trust and adoption],
  [8], [Tsolakidis et al.~(2024), #emph[AI and ML Technologies for Personalized Nutrition: A Review]], [Personalized nutrition], [Review AI/ML for nutrition], [Review], [Personalized nutrition is increasingly recommender-driven], [Bridge to nutrition science],
  [9], [Zheng (2017), #emph[Multi-Stakeholder Recommendation: Applications and Challenges]], [MSR], [Define MSR and agenda], [Conceptual paper], [Recommendation involves multiple legitimate utilities], [Core theory],
  [10], [Abdollahpouri & Burke (2019), #emph[Multi-stakeholder Recommendation and its Connection to Multi-sided Fairness]], [MSR], [Connect MSR with fairness], [Conceptual paper], [Fairness is central in multi-stakeholder settings], [Governance foundation],
  [11], [Wu et al.~(2021), #emph[Multi-FR]], [Fairness-aware RS], [Optimize across stakeholder interests], [Multi-objective framework], [Multi-objective optimization can balance utilities], [Strong precedent for scoring models],
  [12], [Burke et al.~(2018), #emph[Balanced neighborhoods for multi-sided fairness in recommendation]], [Fairness-aware RS], [Improve fairness in exposure], [Fairness-aware method], [Rankings can reduce one-sided bias], [Relevant for equitable food exposure],
  [13], [Tran et al.~(2021), #emph[Recommender systems in the healthcare domain]], [Health RS], [Review healthcare RS], [State-of-the-art review], [Food RS fit within digital health RS], [Useful positioning paper],
  [14], [Roy et al.~(2015), #emph[Food environment interventions in tertiary education settings]], [Campus food], [Review interventions], [Systematic review], [Tertiary food interventions can improve choices], [Strong campus evidence],
  [15], [Deliens et al.~(2014), #emph[Determinants of eating behaviour in university students]], [Campus food], [Identify drivers of eating behavior], [Qualitative study], [Taste, convenience, peers, price, and availability matter], [Supports context-aware design],
  [16], [Caruso et al.~(2025), #emph[The campus food environment and postsecondary student diet]], [Campus food], [Review links between campus environment and diet], [Systematic review], [Campus food environments influence diet], [Supports ecosystem framing],
  [17], [Dahl et al.~(2024), #emph[Assessing the Healthfulness of University Food Environments]], [Campus food / measurement], [Review methods and tools], [Systematic review], [Assessment methods are heterogeneous], [Useful for KPI design],
  [18], [Peixoto et al.~(2026), #emph[Sustainability in university restaurants]], [Sustainability], [Map strategies in university restaurants], [Scoping review], [Research is still waste-centric], [Reveals gap for integration],
  [19], [Guimarães et al.~(2024), #emph[Plate Food Waste in Food Services]], [Operations / waste], [Quantify plate waste], [Systematic review + meta-analysis], [Food waste is measurable and significant], [Useful for canteen objectives],
  [20], [#emph[Recommender systems and sustainability: a dual perspective] (2026)], [Sustainability + RS], [Review sustainability in RS], [Literature review], [Sustainability should be both outcome and design principle], [Relevant for environmental objectives],
)
= Research Gaps
<research-gaps>
The review identifies five major gaps:

+ #strong[No integrated campus framework] combining consumers, canteens, providers, suppliers, researchers, and administrators in one recommendation ecosystem.
+ #strong[Operational constraints] such as kitchen capacity, inventory, and procurement are rarely integrated into healthy-food recommendation models.
+ #strong[Sustainability variables] such as sourcing, seasonality, and emissions remain weakly linked to recommendation objectives.
+ #strong[Real-world institutional deployments] are still limited.
+ #strong[Governance issues] such as fairness, explainability, consent, and institutional priority weighting are underdeveloped in food-specific applications.

= Conceptual Framework
<conceptual-framework>
== Core proposition
<core-proposition>
Based on the literature, this paper proposes that a university healthy-food ecosystem should be built around a #strong[multi-stakeholder recommendation architecture] rather than a consumer-only app. In this architecture, recommendation is treated as a coordination mechanism across multiple actors.

== Key stakeholders
<key-stakeholders>
The proposed ecosystem includes:

- consumers: students, professors, support staff,
- canteens and food-service operators,
- food providers and caterers,
- raw-food suppliers,
- healthy-food researchers,
- university administration.

== Core system modules
<core-system-modules>
A future implementation should include:

- personalized meal recommendation,
- group or shared-choice recommendation,
- multi-objective optimization,
- demand forecasting,
- menu optimization,
- procurement recommendation,
- sustainability scoring,
- explanation interfaces,
- intervention and nudge testing,
- governance mechanisms for fairness and consent.

= Implications
<implications>
== Theoretical implications
<theoretical-implications>
This review shows that the proposed topic is best understood as an #strong[integration problem] across multiple literatures @bondevik2024@zheng2017msr@peixoto2026sustainability. It extends food recommender systems from user-level personalization toward ecosystem-level coordination and applies multi-stakeholder recommendation logic to a food-service setting with strong public-health and sustainability relevance.

== Practical implications
<practical-implications>
For universities, the framework offers a blueprint for redesigning campus dining as an integrated ecosystem rather than a set of isolated outlets. It suggests that healthy-food promotion, waste reduction, procurement stability, and sustainability should be coordinated rather than treated as separate projects.

== Methodological implications
<methodological-implications>
Future studies should combine design science, system prototyping, stakeholder modeling, and field deployment to test whether multi-stakeholder food recommendation improves healthy-food uptake and institutional viability.

= Conclusion
<conclusion>
This paper reviewed literature relevant to a #strong[multi-stakeholder healthy-food ecosystem for university campuses] and found strong support for each component of the concept, but limited integration across them. Campus food environment research validates the setting, food recommender research validates the mechanism, multi-stakeholder recommendation provides the theory, and sustainability research highlights operational priorities. The main opportunity for future work is to combine these strands into a coherent campus ecosystem architecture that balances health, affordability, operational feasibility, sustainability, and institutional governance.

= Journal-Ready Methodology and Architecture
<journal-ready-methodology-and-architecture>
== Methodology
<methodology>
=== Research design
<research-design>
This study adopts a #strong[design science and simulation-based research] approach to develop and evaluate a #strong[multi-stakeholder healthy-food ecosystem] for university campuses. The proposed artifact is an integrated socio-technical system composed of four tightly connected layers: #strong[stakeholders], #strong[food flow], #strong[decision support], and a #strong[multi-stakeholder recommendation system (MSRS)]. For experimental evaluation, the ecosystem is specified as a #strong[multi-agent system (MAS)] in which autonomous stakeholders interact within a shared campus food-service environment. Formally, the system may be represented as $M A S = \( A \, E \, F \, O \, P \, U \, T \)$, where $A$ denotes the set of agents, $E$ the environment, $F$ the food-flow states and transitions, $O$ the observations available to each agent, $P$ the decision policies, $U$ the stakeholder-specific utility functions, and $T$ the temporal transition rules. The agent set includes consumers, canteens, suppliers, research/policy actors, administrators, and an MSRS coordinator. The environment contains menus, inventory, kitchen capacity, supplier pipelines, prices, queues, waste, and policy settings, while food entities move through state-based transitions from raw ingredients to preparation, serving, consumption, and waste. Each agent observes a subset of the system state and chooses actions according to its objectives and constraints. Consumer agents maximize taste, health, affordability, and convenience; canteen agents maximize margin, feasibility, and service quality while minimizing waste; supplier agents maximize order stability and fulfillment performance; and administrative actors maximize health, sustainability, fairness, and affordability outcomes. The MSRS coordinator agent ranks candidate actions using a weighted ecosystem objective and generates coordinated recommendations for meal choice, menu planning, procurement, pricing, and interventions. This framing is appropriate because multi-stakeholder recommendation research treats recommendation as a setting with multiple legitimate utilities, while agrifood digital-twin and simulation literature supports virtual experimentation for food-flow, operational, and sustainability decisions @zheng2017msr@abdollahpouri2019fairness@wu2021multifr.

=== Ecosystem architecture
<ecosystem-architecture>
The ecosystem is modeled as a layered architecture:

+ #strong[Stakeholder layer]
+ #strong[Food-flow layer]
+ #strong[Decision-support layer]
+ #strong[MSRS optimization layer]
+ #strong[Governance and monitoring layer]

This layered structure enables the integration of physical food operations with digital intelligence and coordinated decision-making @zheng2017msr@wu2021multifr.

=== Stakeholder model
<stakeholder-model>
The stakeholder layer includes:

- #strong[Consumers:] students, faculty, and staff
- #strong[Food-service operators:] canteens, caterers, kitchen managers
- #strong[Supply actors:] raw-food suppliers, processors, distributors
- #strong[Governance actors:] nutrition researchers, sustainability office, university administration

Each stakeholder group $s$ is represented by: - a utility function $U_s$, - constraints $C_s$, - decisions $D_s$, - and performance measures $K_s$.

Typical utility structures include: - consumer utility: taste, affordability, health, convenience; - canteen utility: margin, feasibility, throughput, waste reduction; - supplier utility: demand stability, order visibility, spoilage reduction; - university utility: health promotion, sustainability, fairness, and policy compliance.

=== Food-flow model
<food-flow-model>
The food system is modeled as a directed network:

$ G = \( N \, E \) $

where $N$ denotes process nodes and $E$ denotes flow links. The main food-flow chain is:

#strong[Raw material supply → inbound logistics → storage → preprocessing → recipe assembly → cooking/preparation → serving/display → purchase → consumption → leftovers/returns → waste or recovery]

Each food entity is characterized by: - quantity, - unit cost, - lead time, - shelf life, - nutritional profile, - expected taste score, - sustainability score or carbon footprint, - preparation time, - spoilage/waste risk, - selling price.

=== Decision-support system
<decision-support-system>
The DSS is modeled as four modules.

==== Data module
<data-module>
- POS transactions
- recipe and nutrition databases
- inventory and procurement records
- supplier deliveries
- queue and service-time data
- user preferences and ratings
- waste audits
- sustainability attributes

==== Analytics module
<analytics-module>
- demand forecasting
- inventory monitoring
- waste prediction
- taste preference learning
- price sensitivity estimation
- nutrition scoring
- sustainability scoring

==== Decision module
<decision-module>
- menu planning
- procurement planning
- production scheduling
- dynamic pricing and subsidy suggestions
- recommendation ranking
- intervention and nudge selection

==== Execution module
<execution-module>
- consumer app
- canteen dashboard
- supplier portal
- researcher dashboard
- administrative control panel

=== MSRS model
<msrs-model>
The MSRS evaluates candidate actions $a$ using a weighted multi-stakeholder objective:

$ S c o r e \( a \) = sum_s w_s U_s \( a \) $

where: - $U_s \( a \)$ is the utility of stakeholder $s$ under action $a$, - $w_s$ is the policy weight assigned to stakeholder $s$.

The MSRS generates differentiated outputs for multiple actors: - #strong[Consumers:] meal recommendations, bundles, substitutions - #strong[Canteens:] prep quantities, menu mix adjustments, markdown timing - #strong[Suppliers:] replenishment plans, sourcing alternatives - #strong[Researchers/administrators:] nudges, labels, subsidy rules, intervention placement

=== Governance layer
<governance-layer>
A cross-cutting governance layer oversees the entire architecture through: - fairness controls, - explainability, - consent and privacy management, - policy-weight management, - KPI monitoring and auditability.

=== Simulation strategy
<simulation-strategy>
To evaluate the proposed ecosystem, the study uses a #strong[hybrid simulation design]:

- #strong[Agent-based modeling (ABM)] for stakeholder behavior and adaptation
- #strong[Discrete-event simulation (DES)] for kitchen operations, queues, inventory depletion, and deliveries
- #strong[System dynamics (SD)] for longer-term feedback loops such as demand-waste interactions and policy effects

=== Experimental scenarios
<experimental-scenarios>
The simulation compares four scenarios:

+ #strong[No recommender]
+ #strong[Consumer-only recommender]
+ #strong[Rule-based healthy menu planning]
+ #strong[Full MSRS-enabled ecosystem]

Experimental factors include: - demand volatility, - budget pressure, - supplier disruption, - taste-preference heterogeneity, - subsidy intensity, - sustainability-priority settings.

=== Evaluation metrics
<evaluation-metrics>
Performance is evaluated across six dimensions:

- #strong[Consumer:] healthy meal uptake, taste satisfaction, affordability compliance, recommendation acceptance
- #strong[Operations:] forecast accuracy, wait time, stockouts, waste, capacity use
- #strong[Financial:] margin, meal cost, subsidy efficiency
- #strong[Sustainability:] carbon footprint per meal, local/seasonal sourcing, total waste
- #strong[Supplier:] order variability, fill rate, spoilage
- #strong[Governance:] fair access, utility balance, explainability/trust

Improvement should be demonstrated through: 1. #strong[statistical significance] across simulation replications, 2. #strong[practical significance] using relative gains and effect sizes, 3. #strong[Pareto improvement] across health, taste, price, and sustainability trade-offs.

== System Architecture Description
<system-architecture-description>
The proposed architecture links the physical flow of food with digital recommendation and governance.

=== Stakeholder layer
<stakeholder-layer>
The top layer contains all actors: consumers, canteens, suppliers, researchers, and administrators. These actors contribute data, receive recommendations, and adapt their decisions over time.

=== Food-flow and operations layer
<food-flow-and-operations-layer>
This layer represents the physical transformation chain from raw ingredients to ready-to-consume meals and waste streams:

#strong[Raw ingredients → logistics → storage → preprocessing → assembly → cooking → serving → purchase → consumption → leftovers/waste]

=== Data integration layer
<data-integration-layer>
This layer aggregates: - user profiles, - transactions, - recipes and nutrition, - stock and procurement, - delivery records, - queue data, - waste logs, - sustainability indicators.

=== Analytics and DSS layer
<analytics-and-dss-layer>
This layer transforms data into decisions through: - forecasting, - waste analytics, - nutrition and taste modeling, - price modeling, - sustainability scoring, - intervention analytics.

=== MSRS optimization layer
<msrs-optimization-layer>
This is the coordination core. It ranks meals and actions according to multi-stakeholder utility and returns tailored outputs to each actor group.

=== Governance and monitoring layer
<governance-and-monitoring-layer>
This layer overlays all others and manages: - fairness, - transparency, - privacy, - policy priorities, - KPI reporting.

=== Value co-creation logic
<value-co-creation-logic>
Value is co-created when coordinated recommendations improve several stakeholder objectives simultaneously: - #strong[product innovation] through new recipes and substitutions, - #strong[effectiveness] through healthier and more accepted choices, - #strong[efficiency] through lower waste and better forecasting, - #strong[taste] through improved preference-fit, - #strong[price] through affordability and sourcing efficiency.

== Simulation Experiment Design
<simulation-experiment-design>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Component], [Specification], [Rationale],),
  table.hline(),
  [#strong[Objective]], [Evaluate whether an MSRS-enabled campus food ecosystem improves health, taste, affordability, efficiency, and sustainability relative to baseline systems], [Tests ecosystem-level value of MSRS],
  [#strong[Model type]], [Hybrid #strong[ABM + DES + SD]], [Captures heterogeneous actors, operational events, and long-term feedback],
  [#strong[Unit of analysis]], [Campus food ecosystem over daily, weekly, and semester horizons], [Supports both operational and strategic evaluation],
  [#strong[Agents]], [Consumers, canteens, suppliers, researchers, administrators], [Represents multi-stakeholder behavior],
  [#strong[Food entities]], [Ingredients, recipes, prepared meals, served meals, leftovers, waste streams], [Represents end-to-end food flow],
  [#strong[Decision engine]], [Forecasting + DSS + MSRS optimizer], [Simulates coordinated decision support],
  [#strong[Baseline scenario 1]], [No recommender], [Pure operational reference],
  [#strong[Baseline scenario 2]], [Consumer-only recommender], [Compares against standard personalization],
  [#strong[Baseline scenario 3]], [Rule-based healthy menu planning], [Compares against non-learning policy approach],
  [#strong[Treatment scenario]], [Full MSRS-enabled ecosystem], [Main intervention condition],
  [#strong[Time step]], [Daily operational step; weekly planning cycle; semester evaluation], [Matches food-service decision frequency],
  [#strong[Demand conditions]], [Low, medium, high volatility], [Tests robustness to uncertainty],
  [#strong[Budget conditions]], [Low, medium, high consumer budget pressure], [Tests affordability sensitivity],
  [#strong[Supply conditions]], [Stable supply vs disrupted supply], [Tests resilience],
  [#strong[Preference conditions]], [Homogeneous vs heterogeneous taste-health preferences], [Tests personalization value],
  [#strong[Policy conditions]], [Different subsidy levels and sustainability weights], [Tests policy sensitivity],
  [#strong[Consumer outcomes]], [Healthy meal uptake, taste satisfaction, affordability compliance, recommendation acceptance, repeat purchase], [Measures user-facing success],
  [#strong[Operational outcomes]], [Forecast accuracy, stockouts, wait time, capacity use, food waste], [Measures efficiency and feasibility],
  [#strong[Financial outcomes]], [Margin, cost per meal, healthy meal revenue share, subsidy efficiency], [Measures economic viability],
  [#strong[Sustainability outcomes]], [Carbon footprint per meal, local/seasonal sourcing rate, total waste, packaging waste], [Measures environmental performance],
  [#strong[Supplier outcomes]], [Order variability, fill rate, lead-time reliability, spoilage], [Measures upstream coordination],
  [#strong[Governance outcomes]], [Fair access, stakeholder utility balance, explainability/trust], [Measures legitimacy and equity],
  [#strong[Statistical analysis]], [Multiple replications; confidence intervals; pairwise tests and multi-scenario comparison], [Tests significance],
  [#strong[Practical significance]], [% improvement, effect sizes, relative gain vs baseline], [Tests real usefulness],
  [#strong[Trade-off analysis]], [Pareto frontier across health, taste, price, and waste], [Tests multi-objective superiority],
  [#strong[Robustness analysis]], [Stress tests under disruption, price shock, and demand shifts], [Tests stability of improvements],
  [#strong[Success criterion]], [MSRS outperforms baselines on key KPIs without major loss to any stakeholder group], [Demonstrates balanced value co-creation],
)
=== Example hypotheses
<example-hypotheses>
- #strong[H1:] The MSRS scenario yields significantly higher healthy meal uptake than the consumer-only recommender.
- #strong[H2:] The MSRS scenario significantly reduces food waste and stockouts compared with rule-based menu planning.
- #strong[H3:] The MSRS scenario improves the combined ecosystem performance score without reducing taste satisfaction or affordability.
- #strong[H4:] The MSRS scenario produces more favorable Pareto trade-offs across health, taste, price, and sustainability than all baselines.

= Hypothetical Results
<hypothetical-results>
== Overview of comparative performance
<overview-of-comparative-performance>
To illustrate the managerial value of the proposed framework, we report a set of #strong[hypothetical simulation results] comparing four scenarios: #strong[no recommender], #strong[consumer-only recommender], #strong[rule-based healthy menu planning], and the #strong[full MSRS-enabled ecosystem]. Across repeated simulation runs, the MSRS scenario outperforms all baseline conditions on the majority of ecosystem-level indicators while avoiding major losses in any stakeholder group.

In the hypothetical results, the MSRS scenario increases #strong[healthy meal uptake] by approximately #strong[18--26%] relative to the no-recommender baseline and by #strong[8--14%] relative to the consumer-only recommender. At the same time, #strong[taste satisfaction] remains stable or improves slightly, suggesting that the system does not achieve health gains by sacrificing perceived meal quality. #strong[Affordability compliance] also improves because the decision-support layer uses pricing, bundling, and substitution logic to keep recommended meals within student budget constraints.

== Operational and sustainability results
<operational-and-sustainability-results>
Operationally, the MSRS scenario yields improvements in #strong[forecast accuracy], #strong[stockout reduction], and #strong[food waste minimization]. In the hypothetical simulation, forecast accuracy improves from roughly #strong[72--78%] in baseline settings to #strong[84--89%] under the full ecosystem model. Plate and production waste fall by #strong[12--21%], primarily because the system aligns menu planning, demand forecasting, and procurement more effectively. Queue time remains within acceptable limits, indicating that healthier and more diversified offerings do not create excessive service bottlenecks.

The environmental results are also favorable. The MSRS scenario lowers the #strong[carbon footprint per meal] through more targeted sourcing, better menu composition, and lower waste. In the hypothetical runs, carbon intensity declines by #strong[9--16%], while the share of #strong[local/seasonal sourcing] rises under scenarios where sustainability receives moderate or high policy weight.

== Stakeholder utility results
<stakeholder-utility-results>
The simulated stakeholder-utility analysis shows that the full MSRS model produces the most balanced outcome across actors. Consumers gain through improved choice relevance, health fit, and affordability; canteens gain through waste reduction and better production planning; suppliers gain through lower order volatility and better visibility; and administrators gain through improved health and sustainability KPIs. Although some scenarios produce small trade-offs, the MSRS condition dominates baseline approaches on the combined ecosystem performance score and produces a more favorable Pareto frontier across #strong[health], #strong[taste], #strong[price], and #strong[waste].

== Illustrative summary table
<illustrative-summary-table>
#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,right,right,right,right,),
  table.header([Metric], [No recommender], [Consumer-only recommender], [Rule-based planning], [Full MSRS ecosystem],),
  table.hline(),
  [Healthy meal uptake (%)], [31], [39], [42], [49],
  [Taste satisfaction (1--5)], [3.9], [4.0], [3.8], [4.1],
  [Meals within budget (%)], [68], [73], [75], [82],
  [Forecast accuracy (%)], [74], [77], [81], [87],
  [Food waste per 100 meals (kg)], [18.5], [16.9], [15.8], [13.9],
  [Carbon footprint per meal (kg CO2e)], [2.40], [2.31], [2.20], [2.02],
  [Supplier order variability index], [1.00], [0.94], [0.88], [0.76],
  [Ecosystem performance score (0--100)], [56], [64], [69], [81],
)
These results are illustrative and are intended to demonstrate the type of empirical pattern that would validate the framework once fully implemented and simulated.

= Discussion
<discussion>
== Engineering management implications
<engineering-management-implications>
The hypothetical findings suggest that the proposed framework is relevant to engineering management because it shifts the design problem from isolated optimization to #strong[ecosystem orchestration]. Rather than treating food-service performance as the outcome of a single actor or department, the framework models value as co-created through coordinated decisions among consumers, operators, suppliers, and governance actors. From an engineering management perspective, this is important because many mission-oriented service systems require cross-boundary coordination, dynamic trade-off management, and performance measurement across multiple objectives rather than a single efficiency metric.

== Value co-creation as a design problem
<value-co-creation-as-a-design-problem>
The results also support the argument that #strong[value co-creation] should be treated as an operationalizable design logic rather than only a conceptual descriptor. In the proposed model, co-creation emerges when coordinated recommendations improve stakeholder utilities simultaneously: healthier and tastier meals are chosen by consumers, waste and uncertainty are reduced for canteens, procurement becomes more stable for suppliers, and institutional goals are advanced for administrators. This extends value co-creation into a form that can be modeled, simulated, and managed.

== Why MSRS adds value beyond consumer personalization
<why-msrs-adds-value-beyond-consumer-personalization>
A key implication of the comparative scenarios is that a #strong[consumer-only recommender] is not sufficient for mission-oriented sustainable systems. Although such a recommender improves relevance at the user level, it does not necessarily improve supply stability, waste, or ecosystem-wide efficiency. The MSRS creates added value because it embeds recommendation inside a broader decision-support architecture that links demand, menu design, procurement, pricing, and sustainability. Thus, the main managerial contribution of the MSRS is not only better personalization, but better #strong[coordination across stakeholder interfaces].

== Broader transferability
<broader-transferability>
Although the present application focuses on campus food services, the framework is transferable to other service ecosystems in which multiple actors co-create value around mission-oriented outcomes. Examples include hospital food services, workplace catering, school meal systems, community health provisioning, and other sustainability-oriented service platforms. More broadly, the model offers an engineering management template for designing digital coordination systems in settings where quality, affordability, operational efficiency, and sustainability must be balanced simultaneously.

= Conclusion
<conclusion-1>
This paper developed a value co-creation modeling framework for #strong[mission-oriented sustainable service ecosystems] and illustrated its application to #strong[healthy, tasty, and affordable campus food services]. The central contribution is the integration of stakeholder modeling, food-flow modeling, decision support, and multi-stakeholder recommendation into a single engineering management architecture. In this formulation, the MSRS is not merely a personalization engine, but a coordination mechanism that helps align consumer preferences, operational feasibility, supplier stability, affordability, and sustainability.

The paper contributes to engineering management by showing how mission-oriented ecosystems can be designed as multi-stakeholder systems with measurable value co-creation outcomes. It also demonstrates how recommendation systems can be reframed from user-centric tools into broader mechanisms for ecosystem governance and performance improvement. The proposed framework provides a structured basis for future empirical work, simulation experiments, and field implementation in campus food services and analogous service ecosystems.

= Future Work
<future-work>
Future research should extend the present framework in five directions. First, the model should be implemented as a full #strong[simulation environment or digital twin] in order to test sensitivity to demand volatility, policy weighting, supply disruptions, and consumer heterogeneity. Second, future studies should estimate stakeholder utility functions empirically using transaction data, survey data, interviews, and operational records. Third, field studies should examine whether the framework improves outcomes in real campus dining settings and whether observed gains are robust over time.

Fourth, future work should examine governance issues in greater depth, particularly fairness across user groups, explainability of recommendations, and the managerial legitimacy of stakeholder-weight assignments. Finally, the framework should be generalized beyond campus food services to other sustainable service ecosystems in which mission-oriented innovation depends on coordinated digital decision support. Together, these directions would move the framework from conceptual and simulation-based design toward validated engineering management practice.

= References
<references>
== Core references used in the synthesis
<core-references-used-in-the-synthesis>
- Bondevik et al.~(2024). #emph[A systematic review on food recommender systems].
- Tran et al.~(2018). #emph[An overview of recommender systems in the healthy food domain].
- Trattner & Elsweiler (2017). #emph[Food Recommender Systems: Important Contributions, Challenges and Future Research Directions].
- Ge et al.~(2015). #emph[Health-aware Food Recommender System].
- Zheng (2017). #emph[Multi-Stakeholder Recommendation: Applications and Challenges].
- Abdollahpouri & Burke (2019). #emph[Multi-stakeholder Recommendation and its Connection to Multi-sided Fairness].
- Wu et al.~(2021). #emph[Multi-FR: A Multi-objective Optimization Framework for Multi-stakeholder Fairness-aware Recommendation].
- Burke et al.~(2018). #emph[Balanced neighborhoods for multi-sided fairness in recommendation].
- Roy et al.~(2015). #emph[Food environment interventions to improve the dietary behavior of young adults in tertiary education settings].
- Deliens et al.~(2014). #emph[Determinants of eating behaviour in university students].
- Caruso et al.~(2025). #emph[The campus food environment and postsecondary student diet: a systematic review].
- Dahl et al.~(2024). #emph[Assessing the Healthfulness of University Food Environments: A Systematic Review of Methods and Tools].
- Peixoto et al.~(2026). #emph[Sustainability in university restaurants: a scoping review of evaluation focus and strategies].
- Guimarães et al.~(2024). #emph[Plate Food Waste in Food Services: A Systematic Review and Meta-Analysis].
- Tsolakidis et al.~(2024). #emph[Artificial Intelligence and Machine Learning Technologies for Personalized Nutrition: A Review].
