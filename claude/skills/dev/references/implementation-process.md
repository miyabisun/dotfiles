# Implementation Process

Detailed workflow for implementing features, fixing bugs, and refactoring code. Follow this process to ensure consistent, high-quality delivery.

## Phase 1: Analyze

### Requirements Analysis

- Read the full requirement or bug report before starting
- Identify the expected behavior and acceptance criteria
- Note any constraints (performance, compatibility, security)
- List questions or ambiguities to clarify with the user

### Technology Stack Detection

Run this before codebase exploration to establish the framework context for all subsequent decisions.

1. **Manifest scan** — Read the project's manifest/config files at the repository root (`package.json`, `Gemfile`, `composer.json`, `pyproject.toml`, `build.gradle`, `pom.xml`, `Cargo.toml`, `pubspec.yaml`, `go.mod`, `*.csproj`, etc.) to identify:
   - Programming language(s) and version
   - Framework(s) and version (conventions often differ between major versions)
   - Key libraries and tools (ORM, test runner, linter, bundler, etc.)

2. **Documentation scan** — Read `README.md` and `docs/*.md` (if they exist) to understand:
   - Architecture decisions and project structure rationale
   - Development conventions, contribution guidelines, or style guides
   - Technology-specific configuration or setup instructions

3. **Record findings** — Keep the detected stack in mind throughout all subsequent phases. File placement, naming, patterns, directory structure, and error handling should follow the detected framework's conventions.

### Codebase Exploration

- Identify the entry point for the change
- Trace the execution flow to understand how the feature area works
- Note existing patterns: naming conventions, file organization, error handling style
- Identify tests that cover the affected area
- Check for related documentation or comments

### Impact Assessment

- List all files that will need changes
- Identify potential side effects on other features
- Check for shared utilities or components that might be affected
- Consider backward compatibility implications

### Checklist

- [ ] Technology stack is identified (framework, language, key libraries, versions)
- [ ] Project documentation (README.md, docs/) has been reviewed for conventions
- [ ] Requirements are clear and unambiguous
- [ ] Relevant code has been read and understood
- [ ] Affected files and dependencies are identified
- [ ] Questions have been asked and answered

## Phase 2: Plan

### Approach Definition

- Choose the simplest approach that meets requirements
- Consider at least two alternatives before deciding
- Document trade-offs for non-trivial decisions
- Align the approach with existing architectural patterns

### Change Specification

For each file to be modified, describe:
- What changes are needed
- Why those changes achieve the requirement
- What existing behavior is preserved

### Risk Identification

- **Breaking changes**: Will this change any existing API or behavior?
- **Performance**: Could this change degrade performance?
- **Security**: Does this change handle untrusted input?
- **Data**: Does this change affect data storage or migration?

### Checklist

- [ ] Approach is defined and justified
- [ ] Changes are specified per file
- [ ] Risks are identified and mitigated
- [ ] Plan is presented to user for non-trivial tasks

## Phase 3: Implement

### Coding Guidelines

- Make one logical change per commit or action
- Follow the coding standards consistently
- Write self-documenting code; add comments only for non-obvious logic
- Handle edge cases identified during planning

### Change Management

- Modify only what is necessary — do not "clean up" unrelated code
- Preserve whitespace and formatting in unchanged sections
- If refactoring is needed before the feature, do it as a separate step
- Keep imports organized and remove unused ones

### Testing During Implementation

- Run existing tests frequently to catch regressions early
- Write tests for new behavior as part of implementation, not after
- Test edge cases explicitly
- Verify error paths, not just happy paths

### Checklist

- [ ] Code follows existing patterns and conventions
- [ ] Only necessary changes are made
- [ ] Edge cases are handled
- [ ] No security vulnerabilities introduced

## Phase 4: Verify

### Self-Review

Before presenting changes, review them as if reviewing someone else's code:

- Read every changed line — does it do what is intended?
- Check for off-by-one errors, null/undefined access, resource leaks
- Verify error messages are helpful and include context
- Ensure no sensitive information is logged or exposed
- Confirm no debug code or temporary changes remain

### Testing

- Run the full test suite if feasible
- For new functionality, verify:
  - Happy path works correctly
  - Edge cases are handled
  - Error conditions produce expected results
  - Integration with existing features is not broken

### Security Review

- External input is validated before use
- No injection vulnerabilities (SQL, XSS, command injection, path traversal)
- Authentication and authorization checks are in place where needed
- Sensitive data is not logged or exposed in error messages
- Cryptographic functions use established libraries, not custom implementations

### Checklist

- [ ] Self-review completed
- [ ] Tests pass
- [ ] No security issues
- [ ] No debug code remaining

## Phase 5: Deliver

### Summary

Provide a concise summary covering:
- **What changed**: List of modified files and the nature of changes
- **Why**: Connection to the original requirement
- **How**: Brief explanation of the approach taken
- **Trade-offs**: Any compromises or decisions worth noting

### Follow-Up Items

Document any items that should be addressed later:
- Known limitations of the current implementation
- Performance optimizations that could be made later
- Related improvements that were out of scope
- Technical debt introduced or discovered

### Handoff

- Provide any commands the user needs to run (build, migrate, deploy)
- Note environment-specific considerations
- Highlight any configuration changes needed

## Bug Fix Workflow

When fixing a bug, apply additional steps:

1. **Reproduce**: Understand and confirm the bug before attempting a fix
2. **Root cause**: Identify the actual cause, not just the symptom
3. **Fix scope**: Fix the root cause; avoid band-aid fixes that mask the issue
4. **Regression test**: Verify the fix addresses the reported issue
5. **Related bugs**: Check if the same pattern exists elsewhere in the codebase

## Refactoring Workflow

When refactoring code:

1. **Establish baseline**: Ensure existing tests pass before making changes
2. **Small steps**: Make one refactoring move at a time, verifying tests after each
3. **Behavior preservation**: The external behavior must not change
4. **No feature mixing**: Do not add features during a refactoring — separate the work
5. **Document why**: Explain the motivation for the refactoring
