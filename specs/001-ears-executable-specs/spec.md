# Feature Specification: EARS Executable Specifications

**Feature Branch**: `001-ears-executable-specs`

**Created**: 2026-10-04

**Status**: Draft

**Input**: User description: "Add EARS-notation requirements and property-based correctness properties to this kit, so specifications become executable. Requirements in specs/<feature>/spec.md should be written in EARS form: WHEN <trigger> THE SYSTEM SHALL <response>, plus the other EARS patterns (ubiquitous, state-driven, unwanted-behaviour, optional-feature). The plan should gain a Correctness Properties section mapping each testable requirement to a universally-quantified property that begins 'for any'. Tasks should require a property-based test per property, using the project's existing property-based testing framework where one exists. Must stay language-agnostic - do not hardcode Hypothesis, name the framework per project. Must NOT make properties mandatory for requirements that do not map cleanly to a property. Rationale: no preset in the spec-kit community has ported EARS or property-based testing (verified 0 of 41), and template-plus-verification features do not depend on a skill loading."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Write requirements in EARS form (Priority: P1)

A spec author creating `specs/<feature>/spec.md` writes every functional requirement in one of the five EARS patterns, so each requirement is testable and unambiguous without extra interpretation.

**Why this priority**: This is the core value — executable requirements. Without EARS form, downstream properties and property-based tests have nothing rigorous to anchor to.

**Independent Test**: Can be fully tested by generating a spec from the kit templates and inspecting its Functional Requirements section: every requirement matches one EARS pattern and a reviewer can write an acceptance check from the requirement text alone.

**Acceptance Scenarios**:

1. **Given** a new feature spec authored from the kit templates, **When** the author writes functional requirements, **Then** each requirement uses one of the five EARS patterns (ubiquitous, event-driven, state-driven, unwanted-behaviour, optional-feature).
2. **Given** a requirement describing a triggered response, **When** it is reviewed, **Then** it is in event-driven form `WHEN <trigger> THE SYSTEM SHALL <response>`.

---

### User Story 2 - Map requirements to correctness properties in the plan (Priority: P1)

A planner creating `plan.md` adds a Correctness Properties section that maps each testable requirement to a universally-quantified property beginning with "for any", so design intent is verifiable before implementation.

**Why this priority**: The property mapping is what makes specs executable — it bridges human-readable EARS requirements to machine-checkable properties. Joint P1 with US1; together they are the MVP.

**Independent Test**: Can be fully tested by generating a plan from the kit templates for a spec with testable requirements and verifying each testable requirement has a `for any …` property row, and each non-mapped requirement carries an explicit opt-out reason.

**Acceptance Scenarios**:

1. **Given** a plan authored from the kit templates with testable EARS requirements, **When** the Correctness Properties section is reviewed, **Then** each testable requirement maps to at least one property stated as `for any <domain>, <property>`.
2. **Given** a requirement that does not map cleanly to a universal property, **When** the plan is reviewed, **Then** it is explicitly marked as not mapped with a one-line reason and no property is forced.

---

### User Story 3 - Get property-based test tasks naming the project framework (Priority: P2)

An implementer reading `tasks.md` gets one property-based test task per correctness property, naming the project's existing property-based testing framework (detected per project, never hardcoded), so properties are actually checked.

**Why this priority**: Tasks close the loop from property to verification. P2 because it depends on US1+US2 artifacts existing, but it is required for the end-to-end "executable spec" claim.

**Independent Test**: Can be fully tested by generating tasks from a plan containing correctness properties and verifying each property has a corresponding property-based test task that names the project's framework (or records the chosen framework where none existed).

**Acceptance Scenarios**:

1. **Given** a plan with correctness properties, **When** tasks are generated from the kit templates, **Then** each property has a property-based test task tracing to its requirement and property ID.
2. **Given** a project with an existing property-based testing framework, **When** the test tasks are reviewed, **Then** they name that project's framework rather than a hardcoded default.

---

### Edge Cases

- What happens when a requirement is purely qualitative or UX-judgement based (e.g., "tone is welcoming") and cannot be universally quantified? — It is explicitly exempted from property mapping with a recorded reason; the templates must show this opt-out, not force a vacuous property.
- How does the kit handle a project with no property-based testing framework installed? — The plan records the framework choice (adopt existing, add one, or fall back to example-based tests) and tasks follow that decision; the templates must not assume a framework exists.
- What happens when an author mixes EARS patterns incorrectly (e.g., `WHEN` with a state condition)? — The spec-template guidance with per-pattern syntax plus examples, and the quality checklist EARS item, must make the misuse detectable at review time.
- How does the kit stay language-agnostic across Python / JS / Rust / Swift / Go projects? — No template names a concrete framework (e.g., Hypothesis); the plan/tasks instruct the agent to detect and name the project's framework at planning time.
- What happens under the `lean` preset, which bypasses template files? — Out of scope for enforcement (same constraint as existing addenda: `lean` bypasses templates entirely); the spec documents this as a known limitation rather than trying to fix it.

## Requirements *(mandatory)*

All functional requirements below are written in EARS form to exemplify the notation this feature introduces. Pattern labels in brackets are informative only.

### Functional Requirements

- **FR-001** [ubiquitous]: THE SYSTEM SHALL provide EARS authoring guidance in the spec template covering all five EARS patterns, each with its syntax shape and at least one example.
- **FR-002** [event-driven]: WHEN a functional requirement describes a system response to a trigger event, THE SYSTEM SHALL require it in the form `WHEN <trigger> THE SYSTEM SHALL <response>`.
- **FR-003** [state-driven]: WHILE a defined system state holds, THE SYSTEM SHALL require state-dependent requirements in the form `WHILE <state> THE SYSTEM SHALL <response>`.
- **FR-004** [unwanted-behaviour]: IF an unwanted condition or failure occurs, THEN THE SYSTEM SHALL require the handling requirement in the form `IF <unwanted condition> THEN THE SYSTEM SHALL <required prevention or response>`.
- **FR-005** [optional-feature]: WHERE an optional capability applies, THE SYSTEM SHALL require it in the form `WHERE <optional feature> THE SYSTEM SHALL <response>`.
- **FR-006** [event-driven]: WHEN a plan is authored for testable EARS requirements, THE SYSTEM SHALL provide a Correctness Properties section mapping each testable requirement to at least one universally-quantified property stated as `for any <domain>, <property holds>`.
- **FR-007** [event-driven]: WHEN a correctness property exists in the plan, THE SYSTEM SHALL require a property-based test task in the tasks template that traces to its requirement ID and property ID and names the project's property-based testing framework.
- **FR-008** [unwanted-behaviour]: IF a template names a concrete property-based testing framework as the default (e.g., a language-specific library), THEN THE SYSTEM SHALL be rejected — templates MUST stay language-agnostic and instruct per-project framework detection instead.
- **FR-009** [optional-feature]: WHERE a requirement does not map cleanly to a universal property, THE SYSTEM SHALL NOT require a property for it; the plan MUST record an explicit opt-out with a one-line reason.
- **FR-010** [ubiquitous]: THE SYSTEM SHALL deliver EARS guidance, Correctness Properties, and property-test task rules as template appends (`strategy: "append"`) that function without any agent skill being loaded.
- **FR-011** [state-driven]: WHILE the kit's existing traceability regime is in force, THE SYSTEM SHALL preserve requirement → property → test ID linkage so a requirement with no property/test task is detectable as unbuilt and a test with no requirement is detectable as scope creep.
- **FR-012** [event-driven]: WHEN the project has no property-based testing framework, THE SYSTEM SHALL require the plan to record the framework decision (adopt one, or document example-based fallback) and tasks SHALL follow that recorded decision.

### Key Entities *(include if feature involves data)*

- **EARS Requirement**: A functional requirement written in one of the five EARS patterns (ubiquitous, event-driven, state-driven, unwanted-behaviour, optional-feature); carries a stable ID (e.g., FR-001) and its pattern.
- **Correctness Property**: A universally-quantified statement beginning `for any …` that maps 1:1 (or 1:many) to a testable EARS requirement; carries a property ID and traces to its requirement ID; non-mappable requirements carry an opt-out reason instead.
- **Property-Based Test Task**: A task-item verifying one correctness property across generated inputs; traces to requirement ID + property ID and names the project's detected PBT framework.
- **PBT Framework Reference**: The per-project property-based testing framework named at plan time (detected from the repo, never hardcoded in the kit).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A reviewer unfamiliar with the feature can convert every functional requirement in a kit-generated spec into an acceptance check without asking the author for clarification (sampled over 5 consecutive requirements, 100% convertible).
- **SC-002**: Every testable requirement in a kit-generated plan has a `for any …` correctness property, and every non-mapped requirement carries an explicit opt-out reason (100% of requirements accounted for in a trial spec with ≥8 requirements including ≥2 non-mappable ones).
- **SC-003**: Every correctness property in a kit-generated task list has a corresponding property-based test task naming the project's framework, with zero hardcoded framework names in kit-owned template text.
- **SC-004**: The feature works end-to-end with the methodology skill unloaded — a trial generation of spec + plan + tasks on a scratch repo shows EARS requirements, a Correctness Properties section, and property-test tasks with no skill loaded.
- **SC-005**: Kit self-gate passes on Linux and macOS with the new appends composed (preset resolves all four template layers; generated artifacts contain the new sections in append order; re-run is idempotent with no marker duplication).

## Assumptions

- The kit's preset mechanism (`strategy: "append"` in `preset/preset.yml`) is the delivery vehicle; no core Spec Kit templates are forked or replaced.
- Community-catalog rationale (0 of 41 presets port EARS or property-based testing) is taken from the proposer's verification and is not re-verified here; it motivates but does not constrain the design.
- Per-project PBT framework detection is a plan-time agent activity (inspect repo dependencies / test config); the kit provides the instruction, not a framework registry.
- Projects with no PBT framework are supported via an explicit plan-time decision (adopt a framework or fall back to example-based tests) rather than by mandating a dependency.
- The `lean` preset bypasses template files entirely, so these addenda have no effect under `lean` — same documented constraint as existing addenda; users pick `lean` or this preset, not both.
- Existing conventions hold: requirement IDs (`FR-001`), task IDs (`T00x`), `[P]` parallel markers, phase organisation, and ID-based traceability across spec → plan → tasks.
