# Lightweight NPC Framework Analysis & Rework Plan

## Objective

Analyze the `LightweightNpcs/` framework to understand its architecture, design decisions, networking model and runtime behaviour.

The goal is **not** to preserve the existing implementation.

Instead, identify the concepts that make the framework effective, document them, critique the existing design, and propose a modern replacement called **LightweightUnit**, capable of representing any networked unit in the game.

The resulting documentation should serve as the design foundation for a complete rewrite rather than a direct port.

---

# Deliverables

Create the following documentation inside:

```text
docs/LightweightNpcs/

overview.md
architecture.md
runtime.md
networking.md
rendering.md
migration.md
improvements.md
```

Each document should be self-contained and cross-reference the others where appropriate.

---

# overview.md

Provide a high-level explanation of the framework.

Explain:

* What problem it solves
* Why it exists
* What assumptions it makes
* The overall execution flow

Describe the architecture before discussing implementation details.

---

# architecture.md

Document how the framework is organized.

For every module explain:

* Purpose
* Responsibilities
* Public API
* Internal responsibilities
* Dependencies
* Which modules depend on it

Explain why the code has been organized this way.

Where possible, create dependency diagrams.

---

# runtime.md

Document the runtime lifecycle.

Include:

* Initialization
* Unit creation
* Registration
* Spawning
* Updates
* Destruction
* Cleanup

Explain how data flows through the system from creation to destruction.

---

# networking.md

Document the networking architecture.

Explain:

* Client responsibilities
* Server responsibilities
* Authority model
* Data replication
* Prediction (if any)
* Serialization strategy

Describe how read/write buffers are currently used.

Then evaluate whether **Zap** would provide a cleaner implementation.

Compare:

Current implementation

↓

Zap-generated networking

Discuss:

* Simplicity
* Maintainability
* Performance
* Type safety
* Debuggability

Recommend how the networking layer should be redesigned.

---

# rendering.md

Document how NPCs are represented visually.

Explain:

* Model creation
* Character updates
* Animation
* Interpolation
* Rendering pipeline

Determine which responsibilities belong on the client.

---

# migration.md

Design a replacement framework called **LightweightUnit**.

Unlike LightweightNPCs, this framework should represent any networked gameplay entity.

Examples include:

* Football players
* Goalkeepers
* Referees
* Spectators
* Training dummies
* NPCs
* Future gameplay entities

The new architecture should avoid assumptions specific to NPCs.

Document:

## Goals

What LightweightUnit should achieve.

---

## Public API

Design a simple public interface.

Examples:

```lua
LightweightUnit.Create(...)
LightweightUnit.Destroy(...)
LightweightUnit.SetState(...)
LightweightUnit.GetComponent(...)
```

---

## Responsibilities

Clearly separate:

* Simulation
* Rendering
* Networking
* Animation
* Prediction

No module should own unrelated responsibilities.

---

## Extensibility

Explain how future systems could integrate.

Examples:

* Animation system
* ECS
* Match simulation
* AI
* Replay system

---

# improvements.md

Critically evaluate the existing implementation.

Do not simply point out flaws.

For every weakness:

* Explain why it is problematic.
* Describe its impact.
* Propose one or more alternative designs.
* Discuss the trade-offs.

Consider topics such as:

* Separation of concerns
* Coupling
* Module boundaries
* Networking abstraction
* Performance
* Memory usage
* Scalability
* Testability
* API design
* Naming
* Extensibility

Whenever the current implementation solves a problem particularly well, explain why it should be preserved.

---

# General Guidelines

* Explain the architecture rather than line-by-line code.
* Recover the design intent behind the implementation.
* Prefer diagrams, sequence diagrams and flowcharts over implementation details.
* Distinguish between accidental complexity and intentional design.
* Treat the current framework as a source of ideas rather than the desired end state.
* Recommend modern Roblox patterns where appropriate.
* Whenever proposing improvements, justify them with concrete architectural benefits rather than personal preference.
* Assume the rewritten **LightweightUnit** framework will become the foundation for all networked entities in the football engine.

---

> **Do not redesign LightweightUnit in isolation. Its architecture should integrate naturally with the engine's planned event-driven, server-authoritative architecture, shared API layer, and future simulation framework (including a possible ECS implementation). Avoid creating another standalone framework that duplicates responsibilities already assigned to engine systems.**

