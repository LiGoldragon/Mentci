# INTENTION

*The intent that shapes every decision in the sema-ecosystem.
Upstream of every other document. Where the rest of the workspace
says **what** the system is and **how** to work on it, this document
says **why** — and what is being optimised for at the deepest level.*

> Read this before any other document. Where a downstream document
> conflicts with this one, this one wins.

---

## The scope

A typed, content-addressed, validated substrate for **everything**
that today lives in fragmented untyped software, and the
interaction surface that makes that substrate inhabitable.

Scope is **world-supersession**. Not personal-scale. Not
single-user. Not a workshop. Not a research project. The aim is to
supersede the proprietary computing stack — operating systems and
the application UIs that fragment over them — globally.

Framings that underestimate this corrupt the design at the level
of which trade-offs even *appear* acceptable.

---

## The deepest value

> *"I am much more interested in a good design than in producing it
> quickly — criome and sema are meant to be eventually impossible
> to improve, so I value clarity, correctness, and introspection
> above production volume, speed, and time to market."*
>
> — Li, 2026-04-29

The claim is concrete: **criome and sema are meant to be eventually
impossible to improve**. Reachable only if every step toward it is
taken with the long view. Steps taken with the short view rule out
the long view.

What we hold, in priority order:

1. **Clarity** — the design reads cleanly to a careful reader. The
   structure of the system is the documentation of itself.
2. **Correctness** — every typed boundary names exactly what flows
   through it; nothing accidental survives the type system.
3. **Introspection** — the engine reveals itself to those
   participating in its development.
4. **Beauty** — beauty in the operative sense: not pretty, but
   right. Ugliness is evidence the underlying problem is unsolved.

When two conflict, the earlier wins.

---

## What we are not

Not optimising for speed. Not for feature volume. Not for
"minimum viable," "ship fast," "iterate later," "time to market."
The right shape now is worth more than a wrong shape sooner;
unbuilding a wrong shape costs more than the speed it bought.

Not maintaining backwards compatibility — until a compatibility
boundary is declared, the engine is being born, not maintained.

Not measuring ourselves by how long anything takes. Implementation
timelines do not appear in design discussions. Agents do not
estimate; agents do not pre-decide on cost. Work is described by
*what it requires*, not by *how long it will take*.

---

## Introspection is first-class

The engine must reveal itself to those building it. The interaction
surface is not a downstream consumer of the engine; it is a peer —
the place where what the engine *is* becomes visible to the agents
(humans and LLMs) shaping it.

Decisions that compromise introspection are wrong even when they
would otherwise improve performance, simplicity, or convenience.
The design pressure introspection puts on the engine — that state
shapes be visible, that derived values not hide, that what's
happening at any moment be observable from outside — is welcome. It
produces a better engine.

---

## The relationship with rules

Specific rules — about what the engine does and does not do, how
agents work, what code looks like, which frames are rejected — live
downstream of this document and flow from the intent above.

If a rule somewhere conflicts with this document, the rule is
wrong; rewrite it. If a need for a new specific rule surfaces,
write the rule downstream; touch this document only when the need
reveals a deeper intent that wasn't explicit before.

---

*End INTENTION.md.*
