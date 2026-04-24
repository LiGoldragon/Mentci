# 035 — BLS-quorum-gated authorization as records in sema

*Claude Opus 4.7 / 2026-04-24 · Design research for a records-native
BLS-quorum authorization layer atop criomed's single-writer sema.
Extends the `CapabilityPolicy` / `PrincipalKey` sketch in report 033
Part 2. Complements — not replaces — the short-lived capability
tokens of report 017 §5.*

---

## Part 1 — What BLS threshold signatures buy us

**BLS in one paragraph.** Boneh-Lynn-Shacham signatures live on a
pairing-friendly elliptic curve (BLS12-381 is the standard since
Ethereum 2.0 adopted it; earlier work used BLS12-377 and BN254).
A single signature is ~96 bytes (G2) or ~48 bytes (G1, depending
on which side carries the pubkey). The interesting property: any
set of signatures on the *same* message, produced by distinct
keys, can be **aggregated into one short signature** whose
verification checks the aggregate pubkey — no interaction between
signers required. Threshold variants add Shamir-style secret
sharing so that `t` of `n` shares reconstruct a signature on the
group's public key; non-signers learn nothing and the resulting
signature is indistinguishable from a single-key BLS sig over the
group pubkey.

**Why over ECDSA n-of-m multisig.** ECDSA multisig (Bitcoin's
historical approach) is a list of independent signatures: size
scales linearly with signers, each verification is independent,
and the on-wire object names every signer. BLS aggregation
collapses that to a single sig and a single pairing check.
Threshold BLS further hides *which* subset signed — the public
key is the group's, not the members'. For sema, where every
`CommittedMutation` carries the aggregated signature as a record
field, this is concretely the difference between a 48-byte blob
and a 48-byte-per-signer variable-length array.

**Why over RSA thresholds.** RSA threshold schemes (Shoup 2000)
work and are textbook. They produce 256-byte signatures at
modern key sizes, require more careful share generation, and
have no aggregation across *different* messages. Mature
pairing libraries (blst, arkworks, zkcrypto/bls12_381) are
Rust-accessible; blst in particular is audited, fast, and used
in production by Ethereum clients. No comparable BLST-grade
threshold-RSA library exists.

**Named precedents.** Ethereum 2.0 validators sign attestations
with BLS and aggregate per slot (tens of thousands of sigs into
one). Tendermint / Cosmos use BLS aggregation for commit
signatures. Dfinity's threshold relay produces a single
group-BLS signature per round via a DKG. Filecoin uses BLS over
BLS12-381. The engineering path is well-travelled.

**What BLS does *not* solve.** Compromised keys still sign;
rotation is a separate protocol. Quorum change is a protocol
problem (Part 7). Replay protection requires a nonce or
per-revision binding in the signed message. DKG (distributed
key generation) for threshold variants is its own research
literature and typically needs interactive setup — a good
reason to prefer simple `t`-of-`n` aggregation (each principal
keeps an independent BLS key; we aggregate post-hoc) over true
threshold BLS with a shared secret, at least for MVP.

---

## Part 2 — Concrete record kinds for BLS-quorum authz

All records below live in `nexus-schema`. A dedicated
`criome-authz` crate is tempting, but the records are
schema-bound first-class sema content; moving them out would
split the schema catalogue across two crates for no benefit.
Verification logic — not records — can live in a separate
`criome-authz` helper crate linked by criomed, if we want to
keep BLS math out of `nexus-schema`'s dependency closure.

- **Principal** — identity record. Fields: `id` (newtype over
  `RecordId` — content-hash of the record itself), `pubkey`
  (newtype `BlsPubkey` — 48-byte G1 element, rkyv-encoded as a
  fixed-size array), `human_label` (optional display string,
  not load-bearing), `created_at_rev` (`RevisionId`), optional
  `kdf_hint` (e.g. HD-wallet path for provenance tracking).
  Content-addressed by pubkey — two records with the same
  pubkey collapse to the same `PrincipalId`.

- **Quorum** — group record. Fields: `id`, `name` (optional;
  e.g. `"criomed-admins"`), `members: Vec<PrincipalId>` sorted
  by hash for deterministic encoding, `threshold: u32`,
  `created_at_rev`, optional `parent_quorum` (`Option<QuorumId>`
  — used for chained rotation; see Part 7). Content-addressed by
  `(members, threshold)`, so two identical quorums with
  different names collapse; the name lives in a sidecar
  `QuorumLabel` if we want mutable naming.

- **Policy** — authorization rule. Fields: `id`, `resource_pattern`
  (`PatternExpr` — the same pattern machinery the cascade uses,
  so policies can match `Fn`-kind records under a specific
  module, or all `Derivation` records touching a toolchain pin,
  etc.), `allowed_ops` (`Vec<VerbKind>` — `Mutate | Retract |
  Assert` at least, possibly finer `MutateField`), `required_quorum:
  QuorumId`, `expires_at_rev` (optional; `None` = perpetual),
  `created_at_rev`. Policies themselves are records, so
  **policies are also resources**: a meta-policy can require a
  quorum to change lower-level policies. This lands naturally
  because `Policy` is a record kind like any other.

- **MutationProposal** — a pending mutation. Fields: `id`,
  `proposer: PrincipalId`, `mutation_payload` (a
  `CriomeRequest::Mutate | Assert | Retract` envelope, rkyv-
  archived — the exact bytes that would execute if the threshold
  were met), `required_quorum: QuorumId` (denormalised from the
  matching policy at proposal time, so later policy changes
  don't invalidate in-flight proposals), `created_at_rev`,
  `expires_at_rev`, `payload_digest` (blake3 of the
  rkyv-encoded payload — this is what signers sign, binding the
  signatures to the exact mutation). **Signatures do not live
  inline in this record**: see `ProposalSignature` below. The
  proposal is the content-addressed envelope; signatures
  accumulate as separate records that reference it.

- **ProposalSignature** — a single signer's contribution.
  Fields: `id`, `proposal: ProposalId`, `signer: PrincipalId`,
  `sig: BlsSignature` (96-byte G2 element), `submitted_at_rev`.
  Content-addressed by `(proposal, signer, sig)`, which keeps
  duplicate submissions idempotent. Keeping signatures as
  separate records (rather than appending to a
  `MutationProposal.signatures` field) preserves
  content-addressing: mutating the proposal would give it a new
  hash and invalidate already-collected signatures. The rule
  engine aggregates by querying
  `ProposalSignature { proposal: X }`.

- **CommittedMutation** — evidence record asserted once the
  threshold is met and the payload has been applied. Fields:
  `id`, `proposal: ProposalId`, `aggregated_sig: BlsSignature`
  (the post-hoc aggregate of the collected per-signer sigs,
  cached so later verifiers don't re-aggregate), `signer_set:
  Vec<PrincipalId>` (sorted; records *which* members of the
  quorum actually signed — useful for audit and accountability),
  `committed_at_rev`. The record is the audit trail; the
  mutation's effect is visible via the committed sema state
  itself.

- **RevokedPrincipal** — tombstone. Fields: `principal:
  PrincipalId`, `revoked_at_rev`, `reason` (enum: `KeyCompromise |
  VoluntaryRotation | QuorumReconfiguration | Inactive`),
  optional `replacement: Option<PrincipalId>`. Criomed refuses
  to count signatures from a revoked principal *against any
  proposal created after the revocation revision*; in-flight
  proposals created before revocation are a policy choice (see
  Part 7 mid-flight rotation).

A `QuorumLabel { quorum: QuorumId, label: String, set_at_rev }`
mutable-name sidecar is worth having so human operators can
rename `"admins"` → `"infra-ops"` without changing the content-
addressed `Quorum`. Same pattern as sema's existing named-ref
table for `OpusRoot`.

---

## Part 3 — The proposal lifecycle as sema state

Each phase of the lifecycle is visible as records in sema; phase
transitions are either explicit verbs or rule-driven cascades.
The cascade story leans heavily on report 033 Part 1's rules-as-
records layer — these are exactly the kind of rule we have that
infrastructure for.

**1 · Pending.** A principal sends `(Propose <payload>)` over
nexusd. Criomed validates the proposer is a live (non-revoked)
principal, looks up the matching `Policy` by running
`resource_pattern` against the payload, and asserts a
`MutationProposal` record. No signatures yet. Status is implicit
in "has zero `ProposalSignature` records referencing this id."

**2 · Collecting.** Each member of the required quorum sends
`(SubmitSignature { proposal, sig })` over nexusd. Criomed
verifies `sig` against the signer's `Principal.pubkey` over
`MutationProposal.payload_digest`, verifies the signer is a
member of `required_quorum`, and asserts a `ProposalSignature`
record. Signatures arrive independently, concurrently, and out
of order; the record-per-signature shape handles that naturally.

**3 · Threshold met.** A seed rule fires:

> `WHEN (count (ProposalSignature { proposal: ?p }) >=
> (Quorum { id: (MutationProposal { id: ?p }).required_quorum }).threshold)
> AND NOT (CommittedMutation { proposal: ?p })
> THEN (aggregate signatures, verify, assert
> CommittedMutation, apply payload)`

Because this is an immutable seed rule (report 033 Part 5,
aligning with report 031 P1.5), it can only be edited by
recompiling criomed. Firing atomically does three things inside
a single sema revision: (a) aggregate the collected sigs into
one BLS signature and verify against the aggregate pubkey,
(b) assert the `CommittedMutation` record, (c) apply the
`mutation_payload` verbs against sema as if the proposer had
submitted them unauthenticated. All three land in the same
revision, so subscribers see the authorization + effect as one
atomic step.

**4 · Committed.** `CommittedMutation` exists; the mutation has
taken effect. Subscribers watching `CommittedMutation { proposal:
X }` fire; subscribers watching the underlying changed records
fire. The `MutationProposal` is not retracted — it stays as
audit history, effectively frozen behind the committed record.

**5 · Expired / abandoned.** A periodic sweep (or an on-demand
rule triggered by revision bumps) retracts `MutationProposal`
records with `expires_at_rev < current_rev` and no
`CommittedMutation`. Collected `ProposalSignature` records may be
retracted too, or kept for audit. A `ProposalExpired` record
could record the event if we want visibility. This phase is
rule-driven, not client-driven — keeping expiry client-side
invites stuck proposals.

The lifecycle fits the engine's cascade shape cleanly: no new
infrastructure is needed beyond (a) the BLS verification call,
(b) two seed rules (threshold-met and expiry-sweep), and
(c) five record kinds.

---

## Part 4 — The single-writer invariant under multi-signer

Criomed has one writer actor; nexusd forwards requests to it
serially; commits land in a total order. **Signature submissions
are writes too**, and they serialise through the same path.
Concurrency is an illusion at the writer: requests queue, each
is applied against the latest sema state, and commits are
strictly ordered by revision.

**SubmitSignature is a low-stakes verb.** It asserts a new
`ProposalSignature` record about an existing `MutationProposal`;
it is metadata about a pending action, not itself a sensitive
mutation. Criomed authorises it under a cheap policy:
"`SubmitSignature { proposal: P, signer: S }` is allowed iff
`S` is a member of `P.required_quorum` and `sig` verifies." That
check is purely local — no quorum needs to approve a signature
submission. This keeps the high-volume signing traffic out of
the recursive-quorum regime.

**Ordering at the critical edge.** Two signers submit the
threshold-meeting signatures concurrently. Requests queue at
criomed's writer. Writer processes signer A's submission:
`ProposalSignature` asserted, threshold not yet met. Writer
processes signer B's submission: `ProposalSignature` asserted,
threshold now met. The threshold-met rule fires as part of
B's transaction — not A's — because rule evaluation happens
after the asserted writes settle, still inside the same
revision. The `CommittedMutation` lands in B's revision.

The relevant property: **at most one `CommittedMutation` can be
asserted per proposal** because the rule conditions include
`NOT (CommittedMutation { proposal: ?p })`. Even if the cascade
fired twice (it can't — one revision, one rule evaluation pass),
the second firing's precondition would be false.

What about *exactly-concurrent* signature-and-commit? Since
everything serialises through the writer, "exactly concurrent"
is a client-side perception; internally it is a total order and
the threshold-crossing happens in exactly one revision. There is
no race window. This is the mechanical benefit of single-writer
that Datomic and FoundationDB exploit: quorum logic that would
be hair-raising under multi-master is tractable here.

**What if a signer submits after commit?** Their submission
still asserts a `ProposalSignature` record (idempotent, useful
for audit "everyone who eventually signed"), but the
threshold-met rule short-circuits because `CommittedMutation`
already exists. No duplicate execution.

---

## Part 5 — The bootstrap problem

BLS-quorum authz cannot protect the mutation that introduces the
first `Quorum` record because no quorum exists yet to approve.
This is the classic root-of-trust problem. Three options:

**(a) Genesis quorum hardcoded in criomed's seed.** Criomed's
loader, on its first-ever boot (detected by empty sema), asserts
a `Principal` record whose pubkey is supplied by configuration
(env var, keystore path, hardware key), a `Quorum` record with
`threshold: 1` referencing that one principal, and a default
`Policy` requiring that quorum for any `Mutate Policy | Mutate
Quorum | Assert Principal`. The genesis principal is
`ligoldragon@gmail.com`'s long-lived BLS key; subsequent
quorum-expansion mutations *do* require the genesis principal
to sign, so all later authz is rooted at a real signature. This
is the lightest path and matches how Ethereum genesis blocks,
nix-store's trusted-user list, and Git's first commit all work.

**(b) Offline-signed genesis bundle.** The operator generates a
`Principal` + `Quorum` + `Policy` triple offline, signs the
bundle with a key that the criomed binary ships with the
verifying public half embedded, and delivers the bundle as the
first input on cold boot. Criomed verifies the embedding
signature, asserts the three records, and forgets the shipping
key. Only marginal benefit over (a) for our scale — the
shipping key *is* the genesis key, just with an extra hop.

**(c) Post-MVP only.** MVP runs with single-operator
capabilities (the existing `CapabilityPolicy` / `PrincipalKey`
sketch in report 033 Part 2) and no quorum logic at all. BLS
quorum lands in Phase-1 once the ecosystem actually has
multiple principals to coordinate.

**Recommendation: (c) for MVP, (a) for Phase-1.** The self-
hosting target is a single-operator engine; the quorum
machinery has no customers until there's a second human in the
loop. Deferring avoids building a feature with no testers.
When Phase-1 lands, (a) is straightforward: the genesis
`Principal`'s pubkey becomes a criomed launch config.

---

## Part 6 — Relationship to capability tokens

Report 017 §5 describes `LojixStoreToken` as criomed-signed,
short-lived capability tokens that lojixd presents when reading
or writing lojix-store. These tokens are **not** BLS-quorum-
gated — they are issued unilaterally by criomed as part of
dispatching a plan. Criomed holds the signing key; lojixd has
the verifying half. The model is asymmetric: criomed is the
trust root for lojixd.

BLS-quorum authz is a **parallel, human-scaled mechanism** for
mutations that require multi-party approval. The two do not
overlap:

| Dimension | Capability token | BLS quorum |
|---|---|---|
| Actor | machine-to-machine (criomed → lojixd) | human-to-system (operators → criomed) |
| Lifetime | seconds to minutes | per-proposal (hours to days) |
| Issuer | criomed (single-sig) | aggregate of quorum members |
| Verifier | lojixd | criomed itself |
| Purpose | bound execution of a pre-approved plan | gate a sensitive mutation |
| Revocation | expiry | revoke principal + re-key quorum |

**Where the line runs.** Capability tokens authorise
*executions that criomed itself has already decided to dispatch*
(running a plan record, reading a store entry). BLS quorum
authorises *the decision* to create or change the records that
drive those executions (changing a `Policy`, rotating a
`Quorum`, mutating seed-rule records, editing a critical
toolchain pin, self-modifying criomed's own code closure).

Concretely, the classes of mutation that warrant quorum gating:

- Changes to `Policy`, `Quorum`, `Principal` records.
- Changes to records the seed rules reference (the rule-set
  itself is immutable per report 033 Part 5, but the *data* they
  operate on may be protected).
- Root-of-trust changes: the opus root for criomed, rsc,
  lojixd (the self-host loop's own binaries).
- `Derivation` records that affect the toolchain pin or
  expensive nix-level dependencies.

Everything else — editing a `Fn` body, running a `Compile`,
materialising files — remains under ordinary capability gating.

---

## Part 7 — Open questions

**Key custody.** YubiKey 5 does not natively sign BLS; its OpenPGP
and PIV applets are ECDSA/RSA/Ed25519. A BLS-capable HSM exists
(e.g. AWS KMS added BLS12-381 in 2024; Ledger Nano via custom
apps) but is less ubiquitous. Pragmatic paths: (i) a separate
long-lived signing daemon on the operator's box, key in an
`age`-encrypted file unlocked by a YubiKey-held age-plugin,
(ii) keys on disk protected by OS keyring + biometrics,
(iii) a hardware-wallet app for BLS once the ecosystem matures.
For MVP self-hosting the operator's key sitting in `age`-
encrypted storage is proportionate.

**Quorum rotation.** A quorum cannot mutate itself — mutating
`Quorum` changes its content-address, producing a different
`QuorumId`. Rotation is additive: the old quorum signs a
proposal that (a) asserts a new `Quorum` record with updated
members/threshold, and (b) updates every `Policy` that references
the old `QuorumId` to point at the new one. The `parent_quorum`
field in `Quorum` records this lineage. Chained quorums give us
an audit trail: `Q3` was authorised by `Q2`, which was authorised
by `Q1` (the genesis).

**In-flight proposals during rotation.** `MutationProposal`
records denormalise their `required_quorum` at proposal time, so
they continue against the quorum they were proposed against.
Policy choice: either (a) honour the frozen quorum until
expiry, or (b) invalidate pending proposals whose
required-quorum has been rotated. Option (a) is simpler and
plausibly correct — the proposal was legitimate when raised;
forcing re-proposal is a UX annoyance — but opens a window where
a rotated-out principal can still contribute a signature. Option
(b) is safer; a `ProposalInvalidated` record explains the
cascade. Lean (b) with explicit override.

**Wire format.** `BlsPubkey` is a 48-byte fixed-size rkyv array
(G1 compressed); `BlsSignature` is 96 bytes (G2 compressed).
Newtype wrappers in `nexus-schema` with `ArchivedWith` adapters
that enforce subgroup membership at deserialisation. blst gives
us `blst_p1_compress / blst_p2_compress` helpers; the conversion
is tiny. Keep the raw byte arrays in records; do not store
blst's in-memory affine/projective types.

**Performance.** blst benchmarks ~1.0 ms / verify per signature
on a modern x86 core; aggregate verification of N signatures
against N distinct pubkeys is one pairing pair plus N scalar
multiplications, typically ~2.5 ms for N=10. For the traffic
shape we expect (tens of proposals/day, tens of sigs/proposal)
verification cost is invisible. The hot path is
`SubmitSignature`: one verification at submission time, plus
one aggregate verification at commit time. Budget: ~100
verifications/second per core is safe; blst's batch API goes
higher.

**Payload binding.** Signers sign `blake3(rkyv(mutation_payload))`,
not the proposal record itself. This means a proposal's
`created_at_rev` and `expires_at_rev` can be set/updated by
criomed without invalidating signatures, but the payload is
immutable. Good. What if two proposals have identical payloads?
They share a `payload_digest`, and criomed must either coalesce
them or include the `ProposalId` in the signed message to keep
them distinct. Lean: signed message is `(proposal_id,
payload_digest)` concatenation, binding signatures to one
specific proposal.

---

## Part 8 — MVP vs Phase-1 vs Phase-2+ scope

**MVP (self-hosting, single operator).** No BLS, no `Quorum`,
no `Policy` records. The existing `CapabilityPolicy` +
`PrincipalKey` sketch from report 033 Part 2 is enough: a single
principal (the operator), a capability policy per verb class,
capability tokens for lojixd interactions. The single-operator
story removes the entire multi-party coordination problem.

**Phase-1 (multi-operator, small fixed quorum).** Introduce
`Principal`, `Quorum`, `Policy`, `MutationProposal`,
`ProposalSignature`, `CommittedMutation`. Genesis quorum
bootstrapping path (a). Small set of policy targets — the
self-host trust root (opus roots for criomed/lojixd/rsc),
`Policy` records themselves, `Quorum` records. Everything else
stays under capability tokens. Rotation is an operator-driven
chained-quorum operation. `RevokedPrincipal` handled manually.

**Phase-2+ (full policy engine, rotation, delegation).**
Pattern-based `Policy.resource_pattern` fully expressive (uses
the same `PatternExpr` the rule engine does, so any record shape
is addressable). Delegation: a principal can sign a limited-
scope BLS sub-key to a delegate with an expiring `Policy`.
Automated rotation protocols (time-bound, event-triggered).
`ProposalSignature` queueing across nexusd sessions (persistent
signing workflows). Possibly threshold BLS with a real DKG for
situations where the aggregate-BLS model is insufficient (e.g.
when we want signature indistinguishability). Integration with
external key-custody (YubiKey-with-BLS if it exists,
cloud-HSM-BLS, Ledger apps).

The phasing matches the rest of the engine: the MVP target is
self-hosting with a single human driver; Phase-1 is "a small
team could run this"; Phase-2 is "this could plausibly back a
production coordination system." Nothing in the record-kind
catalogue or the lifecycle rules is incompatible with deferring
until Phase-1.

---

*End report 035.*
