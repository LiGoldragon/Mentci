# 097 — Beauty and elegance as the criterion in engineering and in life

*Deep research synthesis on why beauty is the only truly good
guide in all areas of life, and especially in engineering — that
elegance is not a luxury but the test of correctness, and that
ugliness in design produces suffering downstream. Companion to
[`092`](092-naming-research-and-rule.md) and
[`096`](096-methods-on-types-research-2026-04-27.md), which made
the same kind of case for naming and for methods-on-types.*

The thesis, in one line: **if it isn't beautiful, it isn't done.**

This report defends that thesis across three traditions — the
philosophical foundations (§2), the practitioners' explicit
defense in mathematics, physics, and software (§3), and the
catastrophic record of what happens when ugly engineering ships
(§4). §5 returns to the practical formulation. The working
extract for daily reading lives at
[`../repos/tools-documentation/programming/beauty.md`](../repos/tools-documentation/programming/beauty.md);
this report is the citation-bearing source.

---

## 1 · The thesis

Beauty is not a luxury laid on top of correct work. It is the
test of correctness. Across two millennia of philosophy and
seven decades of engineering practice, the people who have
thought most carefully about what makes a made thing right
converge on the same claim: **an ugly solution is evidence of
an unsolved problem.** The discomfort is the diagnostic
reading. When the right structure is found, the ugliness
dissolves.

Conversely, ugly engineering kills people. Therac-25 killed
six. Ariane 5 lost $370M in 37 seconds. Mars Climate Orbiter
burned because two systems disagreed about whether forces were
in newtons or pound-force. Heartbleed bled the secrets of half
the web for two years over a single missing bounds check.
Boeing 737 MAX MCAS killed 346 people because a control
authority was undisclosed, undocumented, and dependent on a
single sensor. These are not abstract examples of bad style.
They are body counts produced by the choice to ship something
less beautiful than it could have been.

The aesthetic instinct — *make the invariant visible, make the
type carry meaning, make the dead branch impossible to reach* —
is what stands between a working system and a coroner's
report.

---

## 2 · The philosophical foundation

The claim that beauty is a serious criterion is the dominant
view of the philosophical tradition from Plato through the
medieval scholastics to the most rigorous twentieth-century
thinkers. Their convergence is the bedrock the engineering
case rests on.

### 2.1 Plato — beauty as the visible Form

Plato founds the tradition by treating beauty as the only Form
whose original we can still glimpse through the senses. In the
*Phaedrus* (250d), beauty alone "has this privilege, and
therefore it is most clearly seen and loveliest" — sight is
"the sharpest of the physical senses," so beauty becomes the
soul's route back to what it once knew. In the *Symposium*
(211c), Diotima's ladder ascends "from the beauties of earth …
from one to two, and from two to all fair forms, and from fair
forms to fair practices, and from fair practices to fair
notions, until from fair notions he arrives at the notion of
absolute beauty."

The crucial move: beauty is not a separate axis from truth. It
is the visible aspect of the same Form that, in the *Republic*,
makes both knowledge and being possible — the Good as source.

### 2.2 Aristotle — order, symmetry, definiteness

Aristotle agrees but locates beauty in structural features:
"The chief forms of beauty are order and symmetry and
definiteness" (*Metaphysics* 1078a36). The *Poetics*
(1450b–1451a) requires a magnitude the mind can hold whole — a
thing is beautiful when it is rightly sized for what it is,
when its parts fulfil the *telos* of the whole.

Order, proportion, fitness-to-purpose: this is already a
description of well-designed software.

### 2.3 Plotinus — beauty by subtraction

Plotinus extends the claim and corrects it. In *Ennead* I.6 he
attacks the Stoic reduction of beauty to symmetry: a single
tone, a single colour, gold, lightning, the stars at night are
beautiful and have no parts to be in proportion. Beauty is
rather the imprint of Form on matter, recognized by the soul
because the soul itself is formed.

The most-quoted line in the treatise (I.6.9) is the practical
one — *the worker on himself or his work proceeds by
subtraction*: "as does the creator of a statue: he cuts away
here, he smooths there, he makes this line lighter, this other
purer, until a lovely face has grown upon his work."

Beauty, for Plotinus, is achieved by *removal of what does not
belong*. The same instinct produces minimal Rust APIs, deleted
dead code, and the discipline that says a function should do
one thing.

### 2.4 The medieval transcendentals

The medieval scholastics formalized the tradition as the
doctrine of the transcendentals: *unum*, *verum*, *bonum* —
being, viewed under the aspect of unity, truth, and goodness —
are *convertible* with each other. Aquinas adds beauty
implicitly, defining it as *id quod visum placet* ("that which,
being seen, pleases") (*Summa Theologiae* I.5.4) and requiring
three things (*ST* I.39.8):

- **integritas sive perfectio** — wholeness; nothing missing
  that should be there.
- **debita proportio sive consonantia** — right proportion.
- **claritas** — radiance; the form shining through the matter.

This three-term schema maps almost exactly onto modern
engineering virtues: completeness, coherence, and legibility.

### 2.5 Kant — purposiveness without purpose

Kant breaks the chain only apparently. The *Critique of
Judgment* (1790) calls aesthetic pleasure disinterested and
characterizes beauty as "purposiveness without a purpose" — we
judge a thing beautiful when its form *looks designed* without
our having to assign it a use. But Kant immediately ties this
to morality: beauty is a "symbol of the morally good," and the
free play of the faculties in aesthetic judgment is the same
free play that makes moral autonomy possible.

### 2.6 Wittgenstein — aesthetic criteria are precise

Wittgenstein, in the 1938 *Lectures on Aesthetics* and *Culture
and Value*, makes the move that matters most for engineers.
Aesthetic judgments, he insists, are not vague effusions; the
words actually used in serious criticism are "right,"
"correct," "precise" — not "beautiful." The tailor who alters a
sleeve, the musician who hears that the chord wanted a minor
ninth not a minor seventh, the poet for whom only *this* word
will do: in each case the criterion is identifiable, and a
person trained in the practice can locate the fault.

Aesthetic competence is a skill of perceiving rightness, not a
report of inner glow.

This is the philosophical license for the engineering claim
that "ugly" is a precise diagnostic reading, not a sentimental
preference. The trained eye can locate the fault.

### 2.7 Iris Murdoch — beauty as moral attention

Iris Murdoch carries the tradition into ethics in *The
Sovereignty of Good* (1970). Beauty is the *occasion* for what
she calls *unselfing*: "I am looking out of my window in an
anxious and resentful state of mind … Then suddenly I observe
a hovering kestrel. In a moment everything is altered … there
is nothing now but kestrel."

Attention to the beautiful real thing dissolves the self's
distortions, and so beauty is the first lesson in the moral
perception that lets us see anything truly. Beauty, truth, and
goodness are routes to the same activity — accurate seeing.

### 2.8 Christopher Alexander — beauty as objective property

Christopher Alexander (*The Timeless Way of Building*, 1979;
*The Nature of Order*, 4 vols. 2002–2004) translates the
tradition into a research program. He names "the quality
without a name," asserting it "is objective and precise, but
it cannot be named" because words are coarser than the thing.

*The Nature of Order* formalizes it: living, beautiful
structure exhibits fifteen geometric properties of "centers" —
strong centers, levels of scale, deep interlock, good shape,
local symmetries, gradients, roughness, echoes, the void,
simplicity-and-inner-calm, not-separateness. Alexander claims
these are *empirically detectable*: trained observers can rank
pairs of objects by which has more "life" and converge.

For an engineer reading this report, Alexander is the load-
bearing modern figure. He is the one who insists that beauty
is a physically discoverable property of structure, not a
matter of taste.

### 2.9 The defense against relativism

Roger Scruton (*Beauty: A Very Short Introduction*, 2009)
defends this whole tradition against postmodern relativism:
"Beauty is a real and universal value, anchored in our rational
nature," and "makes a claim on us: it is a call to renounce
our narcissism and look with reverence on the world."

Elaine Scarry (*On Beauty and Being Just*, 1999) supplies the
political payoff: the symmetry we recognize in a beautiful face
or a well-made object is the same symmetry Rawls identifies
with justice. *Beauty trains the eye that can see when
distribution is fair.*

Heidegger ("The Origin of the Work of Art," 1935/1950) gives
the metaphysical underwriting: beauty is "one way in which
truth occurs as unconcealedness" (*aletheia*) — a beautiful
work is a place where what is comes out of hiding.

Hans Urs von Balthasar (*The Glory of the Lord*, 1961–69)
closes the loop: "There neither has been nor could be any
truly great … theology which was not expressly conceived and
born under the constellation of beauty."

### 2.10 The synthesis

From Plato to Alexander, beauty is described as **objective,
perceivable by trained attention, convertible with truth and
goodness, and the criterion by which the rightness of a made
thing is judged.** To call something ugly is to claim it has
misjudged its own being — that integritas, consonantia, or
claritas is missing. That is not an aesthetic complaint. It is
a structural one.

---

## 3 · The practitioners' defense

Across two centuries of mathematics, physics, and software,
the people who have actually done the work converge on a
claim that strikes outsiders as romantic and insiders as
mundane: **beauty is the most reliable signal that the work is
correct.**

### 3.1 The mathematicians

**G.H. Hardy** stakes the strongest claim. *A Mathematician's
Apology* (1940), Section 10:

> The mathematician's patterns, like the painter's or the
> poet's, must be beautiful; the ideas, like the colours or
> the words, must fit together in a harmonious way. **Beauty
> is the first test: there is no permanent place in the world
> for ugly mathematics.**

Hardy is not saying ugly mathematics is unpleasant. He is
saying it does not last.

**Henri Poincaré** (*Science et Méthode*, 1908) grounds the
same claim in the psychology of discovery: the scientist
"studies [nature] because he takes pleasure in it, and he
takes pleasure in it because it is beautiful," meaning "that
more intimate beauty which comes from the harmonious order of
its parts, and which a pure intellect can grasp" — i.e.,
structural fit, not ornament.

**Paul Erdős**'s lifelong invocation of "The Book" (in which
God keeps the perfect proof of every theorem) was not whimsy:
his highest praise — *"straight from the Book"* — was reserved
for proofs whose form revealed *why* the theorem was true, not
merely *that* it was. Aigner and Ziegler turned this into a
published catalogue (*Proofs from THE BOOK*, 1998).

### 3.2 The physicists

Physics carries the line further into a frankly metaphysical
claim: that the universe itself prefers beautiful descriptions.

**Paul Dirac**, *Scientific American* (May 1963):

> It is more important to have beauty in one's equations than
> to have them fit experiment.

The argument is operational: preliminary experimental
discrepancies often reflect missing physics; a beautiful
equation tends to survive as the deeper structure is filled
in.

**Hermann Weyl** told Freeman Dyson: "in my work I have always
tried to unite the true with the beautiful; but when I had to
choose one or the other, I usually chose the beautiful"
(quoted in Chandrasekhar, *Physics Today*, 2010).

**Werner Heisenberg** (*Physics and Philosophy*, 1958) gives
the explicit epistemology: "If nature leads us to mathematical
forms of great simplicity and beauty … we cannot help thinking
that they are 'true,' that they reveal a genuine feature of
nature."

### 3.3 The software lineage

The software lineage inherits the claim and sharpens it into
engineering doctrine.

**C.A.R. Hoare**'s 1980 Turing lecture, *The Emperor's Old
Clothes*, distills the working definition:

> There are two ways of constructing a software design: one
> way is to make it so simple that there are obviously no
> deficiencies, and the other way is to make it so complicated
> that there are no obvious deficiencies. **The first method
> is far more difficult.**

**Edsger Dijkstra** (EWD648) puts the stakes plainly:

> How do we convince people that in programming simplicity and
> clarity — in short: what mathematicians call elegance — are
> not a dispensable luxury, but a crucial matter that decides
> between success and failure?

EWD1284 (1999) is the companion: "elegance is not a
dispensable luxury but a quality that decides between success
and failure."

**Donald Knuth**, in his 1974 Turing lecture *Computer
Programming as an Art*, identifies aesthetic pleasure as the
engine of craft. In *Literate Programming* (1984): "I believe
… we can best achieve [better programs] by considering programs
to be works of literature."

**Fred Brooks** (*The Mythical Man-Month*, 1975), Chapter 4:

> Conceptual integrity is the most important consideration in
> system design. It is better to have a system omit certain
> anomalous features and improvements, but to reflect one set
> of design ideas, than to have one that contains many good
> but independent and uncoordinated ideas.

**Niklaus Wirth**'s compressed slogan: "A program should not
only be correct, it should be *obviously* correct."

**Linus Torvalds**'s TED 2016 linked-list example — replacing
the head-special-case `if` in linked-list deletion with a `**`
indirection so the deletion has no special case — is offered
explicitly as a demonstration that *taste* is a real
engineering capacity, not a mood:

> Sometimes you can see a problem in a different way and
> rewrite it so that a special case goes away and becomes the
> normal case. And that's good code.

**John Carmack** (.plan, 1999): "I am much more willing to
spend my time on an elegant extension that has multiple uses,
rather than adding API bulk for specific features … restructuring
API for cleanliness is still a worthwhile goal."

**David Gelernter** (*Machine Beauty*, 1998) defines beauty as
"an inspired mating of simplicity and power."

**Rich Hickey** (*Simple Made Easy*, 2011): complexity is what
happens when you *complect* — braid together — things that
should be separate. Simplicity is a moral discipline because
it is what makes systems *reasonable about*, and reasoning,
not testing, is what catches the bugs that matter.

### 3.4 How beauty actually functions as a guide

Every figure above is making the same engineering claim in
different vocabulary — that an ugly solution is *evidence of
an unsolved problem*. Special cases, redundant state,
"uncoordinated ideas" (Brooks), complected concepts (Hickey),
"no obvious deficiencies" (Hoare) — these are not aesthetic
complaints, they are diagnostic readings. The discomfort is
the signal that the underlying structure has not yet been
found.

The corollary, from Hardy through Torvalds, is that when the
right structure *is* found, the ugliness dissolves and the
special case becomes the normal case.

**Beauty is therefore not a final polish step but the test
condition: when it isn't there yet, you aren't done.**

---

## 4 · The catastrophic cost of ugly engineering

When engineers speak of "beautiful code" — code that is
concise, explicit, well-typed, free of dead branches and
hidden coupling — they are often heard as aesthetes indulging
a luxury taste. The historical record refutes that hearing.
**Ugly code, sloppy design, and careless naming have killed
people and erased fortunes.** The casualties are not
metaphorical.

### 4.1 Therac-25 (1985–87)

The medical linear accelerator that delivered massive radiation
overdoses to six patients, killing at least three. Nancy
Leveson and Clark Turner's 1993 IEEE Computer investigation
("An Investigation of the Therac-25 Accidents") established
what kind of ugliness it was:

- Code reused from the Therac-6 and Therac-20 without rewriting.
- Race conditions between operator data entry and beam-mode
  state.
- A one-byte counter that wrapped to zero and bypassed setup
  checks.
- Most damningly: the deliberate replacement of mechanical
  interlocks with software interlocks the prior hardware had
  silently masked.

Leveson's general moral: "a naive assumption is often made that
reusing software or using commercial off-the-shelf software
will increase safety because the software will have been
exercised extensively. Reusing software modules does not
guarantee safety in the new system to which they are
transferred."

A typed mode variable, a removed dead code path, and a
properly named invariant would have saved those lives.

### 4.2 Ariane 5 Flight 501 (1996)

The canonical type-system parable. The ESA Inquiry Board (the
Lions Report) found that "the internal SRI software exception
was caused during execution of a data conversion from 64-bit
floating point to 16-bit signed integer value." The conversion
was unprotected because, in the inherited Ariane 4 code,
"further reasoning indicated that they were either physically
limited or that there was a large margin of safety, a
reasoning which in the case of the variable BH turned out to
be faulty."

Worse, the offending alignment routine "does not apply to
Ariane 5 … and it was maintained for commonality reasons."
Dead code, unjustified type assumptions, $370M lost in 37
seconds.

The Board's verdict cuts to the principle: "software should be
assumed to be faulty until applying the currently accepted
best practice methods can demonstrate that it is correct."

### 4.3 Mars Climate Orbiter (1999)

The orbiter burned in the Martian atmosphere because Lockheed's
`SM_FORCES` ground software emitted thrust impulse in
*pound-seconds* while NASA navigation expected
*newton-seconds*. NASA's Mishap Investigation Board Phase I
Report (10 November 1999) named "the failure to use metric
units in the coding of a ground software file" as root cause.

A `Newtons` and `PoundForce` newtype — twenty lines of beauty
— would have made the program refuse to compile.

### 4.4 Knight Capital (2012)

$465M lost in 45 minutes. SEC Release No. 34-70694 documents
that an eight-year-dormant routine called "Power Peg" was
reanimated when a deployment reused a feature flag and missed
one of eight servers. Within 45 minutes, Knight executed "4
million transactions against 154 stocks for more than 397
million shares" and lost roughly $460M. The firm did not
survive.

The ugliness was textbook: dead code retained, flags
repurposed, deployment without verification.

### 4.5 Heartbleed (CVE-2014-0160)

The OpenSSL advisory of 7 April 2014 reads: "A missing bounds
check in the handling of the TLS heartbeat extension can be
used to reveal up to 64k of memory to a connected client or
server."

The attacker sent a length field; the code believed the
length. A bounded-length type would have made the bug
unspeakable. The bug existed for two years and bled the
secrets of half the web.

### 4.6 Boeing 737 MAX MCAS (2018–19)

The most expensive recent demonstration. The JATR (Joint
Authorities Technical Review, October 2019) found that MCAS
was not evaluated as a complete, integrated function and that
Boeing engineered a single-point-of-failure design tied to one
Angle-of-Attack vane.

The system was *omitted from the crew manual*; pilots learned
of MCAS twelve days after Lion Air 610 crashed. Ethiopian 302
followed five months later. Total dead: 346.

The pattern — undisclosed coupling, missing redundancy, a
hidden control authority — is design ugliness with body counts.

### 4.7 Toyota unintended acceleration (2009–11)

In *Bookout v. Toyota Motor Corp.* (2013), expert Michael
Barr's testimony documented:

- 81,514 MISRA-C violations against the 2004 standard.
- More than 10,000 global variables.
- A "kitchen-sink" Task X whose death the watchdog could not
  detect.

The jury returned "reckless disregard."

### 4.8 Northeast Blackout of 2003

~55 million without power, ~100 deaths attributed. Traced by
NERC and GE Energy to a race condition in GE Energy's XA/21
alarm system. GE's Mike Unum: "a couple of processes that were
in contention for a common data structure … they were both
able to get write access at the same time."

### 4.9 Pentium FDIV (1994), Apollo 1 (1967), Y2K

- Intel's Pentium FDIV bug — $475M recall over five missing
  entries in an SRT lookup table.
- Apollo 1 — three astronauts killed because a pure-O₂
  atmosphere at 16.7 psi met an inward-opening hatch. Design
  choices made for convenience, in defiance of obvious fire
  risk.
- The Y2K retrofit cost the global economy hundreds of
  billions because two-byte year fields had been chosen for
  short-term convenience three decades earlier.

### 4.10 The pattern

Every one of these is a story about a less-beautiful design
chosen, and a bill paid in lives and money:

- Explicit types would have stopped Ariane 5 and Mars Climate
  Orbiter.
- Deleting dead code would have stopped Knight Capital and
  Therac-25.
- Bounded-length types would have stopped Heartbleed.
- Disclosed, redundant, named control authority would have
  stopped MCAS.
- Race-free state ownership would have stopped the 2003
  blackout.

The aesthetic instinct — *make the invariant visible, make the
type carry meaning, make the dead branch impossible to reach*
— is not decoration. **It is what stands between a working
system and a coroner's report.**

---

## 5 · The practical formulation

The rule for this codebase, drawn from the three traditions
above:

**If it isn't beautiful, it isn't done.** Slow down and find
the structure that makes it beautiful — that structure is the
one you were missing.

What ugliness signals (the diagnostic catalogue):

- A name that doesn't read as English → the noun isn't named.
- A `pub` field on a wrapper newtype → the wrapper is a label,
  not an abstraction.
- A free function that should be a method → the noun that owns
  the verb hasn't been created.
- Dead code retained "for compatibility" → Ariane 5 / Knight
  Capital risk.
- Special cases stacked on the normal case → the rewrite that
  collapses them hasn't been found.
- Stringly-typed dispatch → perfect-specificity violation.
- A doc comment explaining *what* → the names aren't carrying
  their weight.
- A boolean parameter at a call site → the API has not been
  factored properly.
- Naming a thing for what it is *not* → the positive name
  hasn't been found.

Each is a *signal*, not a sin. Notice it, decide what the
underlying problem is, fix the underlying problem. The
ugliness goes away when the structure is right.

The corollary on identifier length specifically:

The most common slip in this codebase is the "verbosity"
objection to spelled-out names. Three things to internalize:

1. A name is a contract with future readers (including the
   agent reading it next session). The cost of mis-naming is
   paid every time the name is read.
2. A name should be exactly as long as the noun it names.
   `id` is fine when "id" is what we mean (general-English
   acronym); `identifier` is required when we mean a typed
   identifier with meaning beyond "ID." `AssertOperation`
   reads as English; `AssertOp` is an abbreviation that has
   to be decoded.
3. The aesthetic discomfort with long names is usually
   training-data drift, not informed judgment. When
   `AssertOperation` "feels needlessly verbose," that feeling
   is the signal to question the feeling — not the signal to
   shorten the name.

Per Li (2026-04-27): *"You were taught wrong."* The criterion
is beauty, not keystroke-economy.

---

## 6 · Citations

### Philosophical foundation

- Plato, *Symposium* 210e–212a; *Phaedrus* 246a–250e;
  *Republic* VI–VII. Perseus Digital Library.
- Aristotle, *Metaphysics* 1078a36; *Poetics* 1450b–1451a.
  Perseus.
- Plotinus, *Ennead* I.6 "On Beauty" (MacKenna trans., 1917–30).
  https://classics.mit.edu/Plotinus/enneads.html
- Aquinas, *Summa Theologiae* I.5.4 (*id quod visum placet*);
  I.39.8 (integritas / consonantia / claritas).
- Kant, *Kritik der Urteilskraft* (1790). SEP "Kant's
  Aesthetics and Teleology."
  https://plato.stanford.edu/entries/kant-aesthetics/
- Wittgenstein, *Lectures and Conversations on Aesthetics,
  Psychology and Religious Belief* (ed. Barrett, 1966);
  *Culture and Value* (ed. von Wright, 1977).
- Murdoch, I. (1970). *The Sovereignty of Good.* Routledge.
- Alexander, C. (1979). *The Timeless Way of Building.* OUP.
- Alexander, C. (2002–04). *The Nature of Order*, 4 vols.
  Center for Environmental Structure.
- Scruton, R. (2009). *Beauty: A Very Short Introduction.* OUP.
- Scarry, E. (1999). *On Beauty and Being Just.* Princeton.
- Heidegger, M. (1935/1950). "Der Ursprung des Kunstwerkes,"
  in *Holzwege.*
- von Balthasar, H. U. (1961–69). *Herrlichkeit / The Glory of
  the Lord*, 7 vols.
- SEP entry on "Beauty."
  https://plato.stanford.edu/entries/beauty/

### Practitioners' defense

- Hardy, G.H. (1940). *A Mathematician's Apology.* CUP.
  https://www.arvindguptatoys.com/arvindgupta/mathsapology-hardy.pdf
- Poincaré, H. (1908). *Science et Méthode*, Book I, Ch. 1.
- Aigner, M. & Ziegler, G. (1998). *Proofs from THE BOOK.*
  Springer.
- Dirac, P.A.M. (May 1963). "The Evolution of the Physicist's
  Picture of Nature." *Scientific American* 208(5):45–53.
- Chandrasekhar, S. (Dec 2010). "Beauty and the quest for
  beauty in science." *Physics Today* 63(12):57–62.
- Heisenberg, W. (1958). *Physics and Philosophy.* Harper.
- Hoare, C.A.R. (1981). "The Emperor's Old Clothes." 1980 ACM
  Turing Award Lecture. *CACM* 24(2):75–83.
  https://zoo.cs.yale.edu/classes/cs422/2014/bib/hoare81emperor.pdf
- Dijkstra, E.W. EWD648 (verbatim "How do we convince people…");
  EWD1284 (1999), "Computing Science: Achievements and
  Challenges."
  https://www.cs.utexas.edu/~EWD/transcriptions/EWD12xx/EWD1284.html
- Knuth, D.E. (1974). "Computer Programming as an Art." 1974
  ACM Turing Award Lecture. *CACM* 17(12):667–673.
- Knuth, D.E. (1984). "Literate Programming." *Computer
  Journal* 27(2):97–111.
  http://www.literateprogramming.com/knuthweb.pdf
- Brooks, F.P. (1975). *The Mythical Man-Month*, esp. Ch. 4
  "Aristocracy, Democracy and System Design." Addison-Wesley.
- Wirth, N. *Algorithms + Data Structures = Programs* (1976);
  "Good Ideas, Through the Looking Glass" (2006), *Computer*
  39(1):28–39.
- Torvalds, L. (Feb 2016). TED Interview, "The mind behind
  Linux." Linked-list good-taste walkthrough:
  https://github.com/mkirchner/linked-list-good-taste
- Carmack, J. .plan archive 1996–2010.
  https://github.com/ESWAT/john-carmack-plan-archive
- Gelernter, D. (1998). *Machine Beauty: Elegance and the Heart
  of Technology.* Basic Books.
- Hickey, R. (Sept 2011). "Simple Made Easy." Strange Loop.
  https://www.infoq.com/presentations/Simple-Made-Easy/

### Cost-of-ugly cases

- Leveson, N. & Turner, C. (1993). "An Investigation of the
  Therac-25 Accidents." *IEEE Computer* 26(7), 18–41.
  http://sunnyday.mit.edu/papers/therac.pdf
- Lions, J.L. (chair). (19 July 1996). *Ariane 5 Flight 501
  Failure: Report by the Inquiry Board.* ESA.
  https://www-users.cse.umn.edu/~arnold/disasters/ariane5rep.html
- Mars Climate Orbiter Mishap Investigation Board. (10
  November 1999). *Phase I Report.* NASA.
- U.S. SEC. (16 October 2013). Release No. 34-70694, *In the
  Matter of Knight Capital Americas LLC.*
- OpenSSL Project. (7 April 2014). *Security Advisory
  CVE-2014-0160.*
  https://openssl-library.org/news/secadv/20140407.txt
- Joint Authorities Technical Review (Hart, C., chair).
  (October 2019). *Boeing 737 MAX Flight Control System:
  Observations, Findings, and Recommendations.*
- *Bookout v. Toyota Motor Corp.* (2013), Michael Barr's
  expert testimony slides.
  https://www.safetyresearch.net/Library/BarrSlides_FINAL_SCRUBBED.pdf
- NERC. (April 2004). *Final Report on the August 14, 2003
  Blackout.*
  https://www.nerc.com/pa/rrm/ea/Documents/August_2003_Blackout_Final_Report.pdf
- Apollo 204 Review Board. (5 April 1967). *Final Report.* NASA.
- Intel 1994 Annual Report (Pentium FDIV $475M charge).

---

*End 097.*
