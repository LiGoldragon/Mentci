:create concept {
    id: String =>
    domain: String,
    title: String,
    body: String,
    liveness: String
  }

  :create implies {
    from_id: String,
    to_id: String =>
    strength: String,
    reasoning: String
  }

  :create contrasts {
    left: String,
    right: String =>
    dimension: String,
    verdict: String
  }

  :create lineage {
    ancestor: String,
    descendant: String =>
    year: Int,
    transition: String
  }

  :create system {
    name: String =>
    year: Int,
    role: String,
    significance: String
  }

  ?[id, domain, title, body, liveness] <- [
    ["fol", "logic", "First-order logic",
     "Too expressive. Undecidable. Cannot guarantee an answer.", "trusted_fact"],
    ["prolog", "logic", "Prolog",
     "Turing-complete. May loop forever. The agent dies waiting.", "trusted_fact"],
    ["datalog", "logic", "Datalog",
     "The maximal subset of logic programming that guarantees termination. Captures exactly fixpoint logic. The
  Immerman-Vardi theorem proves it computes exactly the polynomial-time queries on ordered databases.", "doctrine"],
    ["rel-algebra", "logic", "Relational algebra",
     "Codd 1970. The mathematical foundation of databases. No recursion.", "trusted_fact"],
    ["sql", "logic", "SQL",
     "Relational algebra made practical. Recursion bolted on via CTEs decades later. Enormous syntactic surface area.",
  "trusted_fact"],
    ["cwa", "epistemology", "Closed-world assumption",
     "What is not known is false. Agents must act, and action requires commitment to a model of reality. Open-world creates
   paralysis — you can never conclude something is false.", "doctrine"],
    ["owa", "epistemology", "Open-world assumption",
     "Absence means unknown, not false. Correct for the Semantic Web. Paralyzing for autonomous agents.", "trusted_fact"],
    ["termination", "safety", "Guaranteed termination",
     "No function symbols means finite Herbrand universe. Fixpoint computation must reach a fixed point. Non-terminating
  queries are liveness failures. Datalog eliminates this by construction, not by timeout.", "doctrine"],
    ["compositionality", "philosophy", "Compositionality",
     "Rules build on rules. The type signature is uniform: Relation to Relation. This is a functor in the
  category-theoretic sense. It maps directly to how chain-of-thought works: decompose, solve, compose.", "doctrine"],
    ["fixpoint", "philosophy", "Least fixed point semantics",
     "The LLM asserts facts and rules. The engine computes the minimal set of consequences. The LLM does creative abductive
   work. Datalog does mechanical deductive work. Neither does what it is bad at.", "doctrine"],
    ["declarative", "philosophy", "Declarative over imperative",
     "An LLM navigates conclusions from premises. That is declarative. Imperative forces it to simulate a machine — control
   flow, state mutation, execution order — each an opportunity for hallucination.", "doctrine"],
    ["surface-area", "engineering", "Minimal syntactic surface",
     "Datalog has roughly 12 syntactic constructs. Python has hundreds. Every additional construct is an opportunity for
  hallucination. Constrained output space means fewer errors.", "trusted_fact"],
    ["monotonicity", "philosophy", "Monotonic reasoning",
     "Adding facts only adds conclusions, never retracts them. This aligns with how LLMs accumulate context — tokens added,
   never removed.", "observation"],
    ["unique-model", "philosophy", "Unique minimal model",
     "Every Datalog program has exactly one minimal model. One set of assertions yields one correct answer. No
  execution-order ambiguity. No mutable state.", "doctrine"],
    ["hippocampus", "architecture", "CozoDB as hippocampus",
     "Not marketing — an architectural thesis. Relational facts for structured knowledge, graph algorithms for relationship
   analysis, vector indices for semantic similarity, time travel for belief revision, embedded deployment for autonomy.",
  "trusted_fact"],
    ["not-programming", "philosophy", "Datalog is not programming",
     "Code is instructions for a computer. Datalog is assertions about reality. An LLM generating Datalog is not
  programming. It is reasoning, and the database is checking its work.", "doctrine"]
  ]
  :put concept {id, domain, title => body, liveness}

  ?[ancestor, descendant, year, transition] <- [
    ["fol",         "prolog",       1972, "restrict to Horn clauses"],
    ["prolog",      "datalog",      1977, "remove function symbols to guarantee termination"],
    ["rel-algebra", "sql",          1974, "make relational algebra practical"],
    ["sql",         "datalog",      1977, "add clean recursive closure"],
    ["datalog",     "datomic",      2012, "immutable facts plus datalog queries"],
    ["datalog",     "souffle",      2016, "compile to parallel C++"],
    ["datalog",     "codeql",       2019, "largest production deployment via GitHub"],
    ["datalog",     "cozodb",       2022, "unify relational, graph, and vector in one language"],
    ["datalog",     "scallop",      2023, "differentiable datalog with provenance semirings"],
    ["datalog",     "google-mangle", 2025, "deductive database for infrastructure"]
  ]
  :put lineage {ancestor, descendant => year, transition}

  ?[from_id, to_id, strength, reasoning] <- [
    ["cwa",              "datalog",        "constitutive", "datalog operates under CWA — negation as failure becomes a
  reasoning tool"],
    ["termination",      "datalog",        "constitutive", "syntactic restrictions on datalog are what guarantee
  termination"],
    ["compositionality", "datalog",        "constitutive", "named rules compose into larger rules — Relation to Relation is
   algebraically closed"],
    ["fixpoint",         "datalog",        "constitutive", "least fixed point is the execution model — assert, derive,
  done"],
    ["declarative",      "datalog",        "constitutive", "datalog is purely declarative — no control flow, no state, no
  execution order"],
    ["surface-area",     "datalog",        "consequential", "minimal grammar means minimal hallucination surface for
  LLMs"],
    ["monotonicity",     "datalog",        "consequential", "standard datalog is monotone — aligns with context
  accumulation in transformers"],
    ["unique-model",     "datalog",        "consequential", "one program, one answer — formal verification of LLM reasoning
   becomes trivial"],
    ["datalog",          "hippocampus",    "enabling",     "cozodb takes the datalog thesis and builds agent memory
  architecture around it"],
    ["not-programming",  "fixpoint",       "reinforcing",  "because the engine derives consequences, the LLM only needs to
  assert truth"]
  ]
  :put implies {from_id, to_id => strength, reasoning}

  ?[left, right, dimension, verdict] <- [
    ["datalog",  "sql",      "recursion",     "native vs bolted-on CTEs"],
    ["datalog",  "sql",      "surface-area",  "12 constructs vs hundreds of keywords"],
    ["datalog",  "sql",      "composability", "rules compose algebraically vs monolithic query blocks"],
    ["datalog",  "prolog",   "termination",   "guaranteed vs may loop forever"],
    ["datalog",  "prolog",   "semantics",     "unique minimal model vs multiple answer substitutions"],
    ["datalog",  "graphql",  "reasoning",     "deductive rules vs schema-coupled data fetching"],
    ["datalog",  "graphql",  "recursion",     "transitive closure is native vs impossible"],
    ["datalog",  "sparql",   "assumption",    "closed-world vs open-world"],
    ["datalog",  "sparql",   "verbosity",     "predicate(args) vs URI-laden triples"],
    ["cwa",      "owa",      "agency",        "CWA enables action through commitment; OWA creates paralysis through
  permanent uncertainty"],
    ["cozodb",   "sqlite",   "query-power",   "datalog with graph algorithms and vector search vs SQL only"],
    ["cozodb",   "neo4j",    "unification",   "relational plus graph plus vector in one language vs graph-only with
  separate tools"],
    ["cozodb",   "datomic",  "deployment",    "embeddable in-process vs client-server"]
  ]
  :put contrasts {left, right => dimension, verdict}

  ?[name, year, role, significance] <- [
    ["gallaire-minker-workshop", 1977, "foundation",  "first workshop on logic and databases"],
    ["logicblox",                2004, "validation",  "proved datalog handles enterprise scale"],
    ["datomic",                  2012, "revival",     "immutable facts plus datalog brought to Clojure community"],
    ["souffle",                  2016, "performance", "compiled datalog to parallel C++ — proved datalog can be fast"],
    ["codeql",                   2019, "scale",       "every GitHub security advisory runs datalog queries"],
    ["cozodb",                   2022, "synthesis",   "relational plus graph plus vector for AI agent memory"],
    ["scallop",                  2023, "neurosymbolic", "differentiable datalog at PLDI — provenance semirings for
  probabilistic reasoning"],
    ["google-mangle",            2025, "industry",    "Google open-sources datalog for deductive infrastructure"]
  ]
  :put system {name => year, role, significance}
