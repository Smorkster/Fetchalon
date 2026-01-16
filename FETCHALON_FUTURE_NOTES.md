# Fetchalon – Future Notes & Roadmap

This document captures **forward-looking notes** about Fetchalon.  
It is intentionally pragmatic and sorted by **relevance and impact (highest first)**.

The goal is not to promise delivery, but to:
- Preserve architectural intent
- Avoid future rework traps
- Communicate direction to contributors and reviewers


## 1. Define a real tool contract (Highest Priority)

**Why it matters**
- Fetchalon currently relies on conventions and implicit knowledge.
- A formal contract is the single biggest step forward.

**What to define**
- Standard input parameters per tool
- Standard output object shape
- Explicit success / failure signaling
- Structured error objects (not raw exceptions)

**Example**
```powershell
[PSCustomObject]@{
    Success = $true
    Message = "Operation completed"
    Data    = $result
    Error   = $null
}
```

**Outcome**
- Predictable GUI bindings
- Safer refactoring
- Easier onboarding


## 2. Centralized Error Handling & User Feedback

**Why it matters**
- Silent failures are dangerous.
- UI currently depends too much on "happy-path" execution.

**Focus areas**
- One shared error-handling module
- UI-level error surface (status bar / modal / toast)
- Clear distinction between:
  - User error
  - Environment error
  - Permission error
  - External service error

**Outcome**
- Increased trust in tool results
- Faster troubleshooting


## 3. Environment & Permission Pre-flight Checks

**Why it matters**
- Many tools assume admin rights, modules, or connectivity.
- Failures often happen *before* business logic runs.

**Ideas**
- `Test-FetchalonEnvironment`
- Module presence checks
- Admin / elevation detection
- Tenant / service connectivity validation

**Outcome**
- Fail fast, fail clearly
- Fewer half-executed operations


## 4. Logging & Auditability

**Why it matters**
- Fetchalon performs impactful operations.
- There is currently no unified audit story.

**Possible scope**
- Central logging function
- Timestamp, user, tool name, result
- Optional export:
  - CSV
  - JSON
  - Windows Event Log

**Outcome**
- Operational accountability
- Easier post-incident analysis


## 5. Explicit Security Model

**Why it matters**
- Current design assumes a trusted operator.
- Limits scalability and enterprise adoption.

**Future considerations**
- Read vs write tools
- Destructive vs non-destructive actions
- Role-based visibility (even if soft-enforced)
- Clear documentation of required privileges per tool

**Outcome**
- Reduced risk
- Easier security review


## 6. UI Consistency & UX Improvements

**Why it matters**
- UX debt accumulation.
- Inconsistent feedback erodes trust.

**Improvements**
- Shared XAML resource dictionary
- Consistent spacing, fonts, and controls
- Progress indicators for long-running tasks
- Keyboard accessibility

**Outcome**
- More professional feel
- Lower cognitive load for operators


## 7. Developer Documentation & Contribution Guide

**Why it matters**
- Knowledge is currently concentrated.
- New contributors face a steep learning curve.

**Suggested docs**
- Project philosophy (what Fetchalon is *not*)
- How to add a new tool
- Naming conventions
- Common pitfalls

**Outcome**
- Bus-factor reduction
- Safer collaboration


## 8. Testing Strategy

**Why it matters**
- PowerShell testing is often ignored.
- Some tools could benefit greatly from validation.

**Ideas**
- Pester tests for:
  - Input validation
  - Output contracts
- Smoke tests for non-destructive tools

**Outcome**
- Confidence during refactors
- Fewer regressions


## 9. Plugin / Extension Model (Low Priority)

**Why it matters**
- Only relevant if Fetchalon grows beyond its current scope.

**Thoughts**
- External tool registration
- Loose coupling via manifests
- Optional loading of tool sets

**Outcome**
- Scalability without core bloat


## 10. Packaging & Distribution (Lowest Priority)

**Why it matters**
- Only needed if Fetchalon becomes widely shared.

**Possibilities**
- Signed scripts
- Versioned releases
- Installer / portable bundle

**Outcome**
- Easier deployment
- Clear version control


## Non-Goals (Important)

Fetchalon is **not** currently aiming to be:
- A commercial product
- A generic PowerShell framework
- A replacement for enterprise admin platforms

Clarity here prevents over-engineering.


## Final Note

Fetchalon already succeeds at its primary goal:
> Solving real administrative problems efficiently.

This roadmap exists to ensure future improvements:
- Add clarity, not complexity
- Add safety, not bureaucracy
- Preserve pragmatism
