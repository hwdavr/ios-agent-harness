# Spec Adhoc — <Feature Name>

Use this template when producing `spec_v<N>.md` in the **Requirement, Impact & Design Analysis** stage for adhoc workflows.

**Date**: YYYY-MM-DD
**Status**: Draft / Final

---

## Requirement Summary
<description>

## Functional Requirements

- **FR-001**: System MUST [specific capability, e.g., "allow users to create accounts"]
- **FR-002**: System MUST [specific capability, e.g., "validate email addresses"]
- **FR-003**: Users MUST be able to [key interaction, e.g., "reset their password"]
- **FR-004**: System MUST [data requirement, e.g., "persist user preferences"]
- **FR-005**: System MUST [behavior, e.g., "log all security events"]

*Example of marking unclear requirements:*

- **FR-006**: System MUST authenticate users via [NEEDS CLARIFICATION: auth method not specified - email/password, SSO, OAuth?]
- **FR-007**: System MUST retain user data for [NEEDS CLARIFICATION: retention period not specified]

---

## Success Criteria *(mandatory)*

- **SC-001**: [Measurable metric, e.g., "Users can complete account creation in under 2 minutes"]
- **SC-002**: [Measurable metric, e.g., "System handles 1000 concurrent users without degradation"]
- **SC-003**: [User satisfaction metric, e.g., "90% of users successfully complete primary task on first attempt"]
- **SC-004**: [Business metric, e.g., "Reduce support tickets related to [X] by 50%"]

---

## Rule Applicability

Copy the complete matrix from
[`rule-applicability-template.md`](rule-applicability-template.md). Keep all nine rows
and replace each `<decision>` with a supported decision before the requirements stage
can pass.

| Rule ID | Rule document | Default | Decision for this change | Trigger / rationale | Planned evidence |
|---|---|---|---|---|---|
| ARCH | `ios-architecture.md` | Always | <decision> | <trigger/rationale> | <evidence> |
| IMPL | `implementation-rules.md` | Always | <decision> | <trigger/rationale> | <evidence> |
| TEST | `testing-strategy.md` | Always | <decision> | <trigger/rationale> | <evidence> |
| SUI | `swiftui-rules.md` | Conditional | <decision> | <trigger/rationale> | <evidence> |
| L10N | `localization-rules.md` | Conditional | <decision> | <trigger/rationale> | <evidence> |
| NAV | `navigation-rules.md` | Conditional | <decision> | <trigger/rationale> | <evidence> |
| API | `api-contract-rules.md` | Conditional | <decision> | <trigger/rationale> | <evidence> |
| OBS | `observability.md` | Conditional | <decision> | <trigger/rationale> | <evidence> |
| ANL | `analytics-rules.md` | Conditional | <decision> | <trigger/rationale> | <evidence> |

---

## Edge Cases

- What happens when [boundary condition]?
- How does system handle [error scenario]?

---

## Explicit Assumptions
1. <assumption>

---

## Open Questions
- <question>
