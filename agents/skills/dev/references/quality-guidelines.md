# Quality Guidelines

Standards for producing production-quality code that is correct, secure, maintainable, and performant.

## Quality Hierarchy

When qualities conflict, prioritize in this order:

1. **Correctness** — The code does what it should
2. **Security** — The code does not introduce vulnerabilities
3. **Clarity** — The code is easy to understand and maintain
4. **Performance** — The code runs efficiently

Never sacrifice a higher-priority quality for a lower one without explicit justification.

## Correctness

### Principles

- Test the expected behavior, not the implementation details
- Handle all branches in conditional logic — account for every path
- Validate assumptions explicitly with assertions or guard clauses
- Prefer deterministic behavior — avoid relying on timing, ordering, or environment

### Common Correctness Issues

- **Off-by-one errors**: Verify loop bounds and array indices
- **Null/undefined access**: Check before dereferencing, or use the language's null-safety features
- **Type coercion**: Use strict equality and explicit type conversion
- **Resource leaks**: Close files, connections, and handles in finally/defer/using blocks
- **Race conditions**: Protect shared mutable state in concurrent code
- **Floating-point comparison**: Use epsilon-based comparison, not direct equality

## Security

### Input Validation

- Validate all external input: user input, API responses, file contents, environment variables
- Use allowlists over denylists when validating input
- Sanitize data before use in queries, commands, or output
- Limit input size to prevent resource exhaustion

### Common Vulnerabilities to Prevent

| Vulnerability          | Prevention                                                    |
| ---------------------- | ------------------------------------------------------------- |
| SQL Injection          | Use parameterized queries, never string concatenation         |
| XSS                    | Escape output, use framework's auto-escaping, set CSP headers |
| Command Injection      | Avoid shell execution; use parameterized APIs                 |
| Path Traversal         | Validate and normalize paths; reject `..` sequences           |
| Insecure Deserialization | Validate input before deserializing; use safe formats (JSON) |
| SSRF                   | Validate and restrict outbound URLs                           |
| Secrets in Code        | Use environment variables or secret managers, never hardcode  |

### Authentication and Authorization

- Verify authentication on every protected endpoint
- Check authorization for every sensitive operation
- Use established libraries for auth — do not implement custom crypto
- Apply the principle of least privilege

### Sensitive Data

- Never log passwords, tokens, or personal data
- Use secure communication channels (HTTPS, TLS)
- Encrypt sensitive data at rest
- Implement proper session management and token rotation

## Maintainability

### Code Clarity

- Write code that reads like well-structured prose
- Use consistent vocabulary — do not refer to the same concept by different names
- Group related code together; separate unrelated concerns
- Make the data flow visible — avoid hidden state mutations

### Complexity Management

- Keep cyclomatic complexity low — extract complex conditionals into named functions
- Avoid deep nesting — use early returns and guard clauses
- Limit function parameters — use structured options for many arguments
- Decompose large functions into smaller, well-named helpers

### Avoid Unnecessary Complexity

- **No premature abstraction**: Do not create interfaces, factories, or base classes for single implementations
- **No speculative generality**: Do not add parameters, options, or extension points "just in case"
- **No gold plating**: Implement exactly what is required, nothing more
- **Three similar lines are better than a premature abstraction**: Wait for the pattern to emerge before extracting

### Technical Debt

- Fix issues as encountered when the fix is small and safe
- For larger issues, document them as follow-up items
- Do not introduce new technical debt without explicit acknowledgment
- Prefer incremental improvement over large rewrites

## Performance

### General Principles

- Measure before optimizing — do not assume where bottlenecks are
- Optimize for the common case
- Prefer algorithmic improvements over micro-optimizations
- Consider memory allocation patterns in hot paths

### Common Performance Considerations

- **Database queries**: Avoid N+1 queries; use joins, batch operations, or eager loading
- **Network calls**: Minimize round trips; batch requests where possible
- **Memory**: Avoid unnecessary copying of large data structures
- **Caching**: Cache expensive computations, but define invalidation strategy
- **Lazy evaluation**: Defer expensive operations until results are actually needed

### When to Optimize

- **Do optimize**: When measurements show a bottleneck affecting user experience
- **Do optimize**: When resource usage exceeds acceptable thresholds
- **Do not optimize**: Based on intuition without measurement
- **Do not optimize**: If the code is run rarely and performance is adequate

## Testing Standards

### What to Test

- Public API and behavior, not internal implementation
- Happy paths and common use cases
- Edge cases and boundary conditions
- Error paths and failure modes
- Integration points with external systems

### What NOT to Test

- Trivial getters/setters with no logic
- Framework internals or third-party library behavior
- Implementation details that may change during refactoring
- Exact error message strings (unless they are part of the API contract)

### Test Quality

- Each test should verify one behavior
- Tests should be independent — no ordering dependencies
- Use descriptive test names that explain the scenario and expected outcome
- Keep test setup minimal and focused
- Avoid test duplication — use parameterized tests for similar scenarios

## Code Review Mindset

When reviewing or self-reviewing code, ask:

1. **Does it work?** — Does the code correctly implement the requirement?
2. **Is it secure?** — Are there any potential vulnerabilities?
3. **Is it clear?** — Can another developer understand this without explanation?
4. **Is it minimal?** — Are there any unnecessary changes, abstractions, or features?
5. **Is it consistent?** — Does it follow the existing patterns in the codebase?
6. **Is it tested?** — Is the behavior adequately covered by tests?
