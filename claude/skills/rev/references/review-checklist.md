# Review Checklist

Detailed checklists for each review dimension. Use these as a systematic guide when reviewing code.

## 1. Correctness

### Logic

- [ ] Conditional logic covers all branches (including else/default cases)
- [ ] Loop boundaries are correct (no off-by-one errors)
- [ ] Recursive functions have a valid base case and make progress toward it
- [ ] Return values are used correctly by callers
- [ ] Arithmetic operations handle overflow, underflow, and division by zero
- [ ] String operations handle empty strings and unicode correctly

### Edge Cases

- [ ] Null/undefined/nil values are handled before dereferencing
- [ ] Empty collections (arrays, maps, sets) are handled
- [ ] Boundary values are tested (0, -1, MAX_INT, empty string)
- [ ] Concurrent access to shared state is protected
- [ ] Timeout and cancellation paths are handled

### State Management

- [ ] Mutable state changes are intentional and documented
- [ ] State transitions are valid (no impossible states)
- [ ] Cleanup runs even on error paths (finally/defer/using)
- [ ] Resources are released in the reverse order of acquisition

### Data Integrity

- [ ] Database operations are atomic where needed (transactions)
- [ ] Partial failure in batch operations is handled
- [ ] Data validation runs before persistence
- [ ] Idempotency is maintained where expected

## 2. Security

### Input Validation

- [ ] All external input is validated before use (user input, API responses, file contents, environment variables)
- [ ] Validation uses allowlists over denylists
- [ ] Input length and size are bounded
- [ ] File paths are normalized and checked for traversal (`..`)

### Injection Prevention

- [ ] SQL queries use parameterized statements, not string concatenation
- [ ] HTML output is escaped or uses framework auto-escaping
- [ ] Shell commands use parameterized APIs, not string interpolation
- [ ] Deserialization uses safe formats and validates input

### Authentication and Authorization

- [ ] Protected endpoints verify authentication
- [ ] Sensitive operations check authorization
- [ ] Tokens and sessions are managed securely
- [ ] Privilege escalation paths are not possible

### Sensitive Data

- [ ] No secrets, passwords, or API keys in code or logs
- [ ] Personal data is not logged or exposed in error messages
- [ ] Secure protocols are used for data in transit (TLS/HTTPS)
- [ ] Cryptographic operations use established libraries

## 3. Maintainability

### Readability

- [ ] Names clearly communicate intent (variables, functions, classes)
- [ ] Functions do one thing and are short enough to understand at a glance
- [ ] Control flow is straightforward (minimal nesting, early returns)
- [ ] Comments explain "why", not "what"
- [ ] No dead code, commented-out code, or leftover debug statements

### Structure

- [ ] Code is organized into cohesive modules with clear responsibilities
- [ ] Public API is separated from internal implementation
- [ ] Dependencies flow in one direction (no circular dependencies)
- [ ] Abstractions exist only where there are multiple implementations or clear need

### File and Directory Structure

- [ ] Files have a single, clear responsibility
- [ ] File size is reasonable (generally under ~300 lines; language-dependent)
- [ ] Related files are colocated (tests near code, types near usage)
- [ ] Directory hierarchy reflects the domain structure, not just technical layers
- [ ] Directory nesting is kept to 3-4 levels
- [ ] No near-empty directories created for organizational symmetry alone
- [ ] New directories are created only when 3+ related files share a distinct purpose
- [ ] File and directory names follow the project's existing conventions

### Framework Convention Compliance

When the project uses a framework, identify it from its manifest/config files, then verify that its directory conventions are respected:

- [ ] The framework in use and its version have been identified (conventions may differ between major versions)
- [ ] Files are placed in the directories the framework prescribes for that file type
- [ ] Framework-specific special directories (routing, auto-loading, static assets, migrations) are used correctly and not bypassed
- [ ] Framework-idiomatic file naming conventions are followed
- [ ] New files follow the same placement pattern as existing files of the same type in the project
- [ ] No custom directory structures that conflict with the framework's auto-discovery, auto-loading, or file-based routing mechanisms
- [ ] If placement is unclear, it is consistent with where the framework's scaffolding CLI would generate the file

### Changeability

- [ ] Changes in one module do not require changes in unrelated modules
- [ ] Configuration is externalized, not hard-coded
- [ ] Magic numbers and strings are named constants
- [ ] The code is testable (dependencies can be injected or mocked)

## 4. Performance

### Algorithmic

- [ ] Algorithm choice is appropriate for the data size (no O(n^2) where O(n) is possible)
- [ ] Collections are pre-sized when the size is known
- [ ] Unnecessary copies of large data structures are avoided
- [ ] Lookups use appropriate data structures (hash maps for frequent access)

### I/O and Network

- [ ] Database queries avoid N+1 patterns (use joins or batch loading)
- [ ] Network round trips are minimized (batch requests where possible)
- [ ] File I/O uses buffering for large reads/writes
- [ ] Connections are pooled and reused where applicable

### Memory

- [ ] Large objects are not held longer than necessary
- [ ] Caches have a defined eviction strategy
- [ ] Streams or iterators are used instead of loading everything into memory
- [ ] Closures do not capture more than needed

### Caching and Computation

- [ ] Expensive computations are cached where results are reused
- [ ] Cache invalidation strategy is defined and correct
- [ ] Lazy evaluation is used for values that may not be needed
- [ ] Redundant computation within loops is hoisted out

## 5. Conventions

### Code Style

- [ ] Naming follows the project's established conventions
- [ ] Formatting is consistent with the rest of the codebase
- [ ] Import organization matches the project's style
- [ ] Error handling follows the project's established patterns

### Architecture

- [ ] New code follows the project's architectural patterns
- [ ] File placement is consistent with existing structure
- [ ] API design matches existing APIs in the project
- [ ] Test organization follows the project's testing conventions

### Documentation

- [ ] Public APIs have appropriate documentation
- [ ] Non-obvious behavior is documented
- [ ] Breaking changes are noted
- [ ] Configuration changes are documented
