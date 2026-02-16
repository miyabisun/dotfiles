# Review Patterns

Common anti-patterns, code smells, and issues to watch for during code review. Organized by category with descriptions and remedies.

## Correctness Anti-Patterns

### Unchecked Null/Undefined Access

**Symptom**: Accessing properties or methods on a value that could be null/undefined without checking first.

**Risk**: Runtime crash (NullPointerException, TypeError, segfault).

**Remedy**: Add guard clause, use optional chaining, or redesign to eliminate the null case.

### Off-By-One Errors

**Symptom**: Loop iterates one too many or one too few times. Array index is out of bounds. Fence-post counting is wrong.

**Risk**: Missing data, index out of bounds, incorrect results.

**Remedy**: Verify loop bounds with concrete examples. Check `<` vs `<=`. Prefer range-based iteration where the language supports it.

### Ignored Return Values

**Symptom**: Calling a function that returns an error or status code without checking the result.

**Risk**: Silent failure. Operation appears to succeed when it has not.

**Remedy**: Handle the return value. If intentionally ignoring, make it explicit (e.g., `_ = result` or a comment).

### Race Conditions

**Symptom**: Multiple threads or async operations access shared mutable state without synchronization. Check-then-act sequences without locking.

**Risk**: Data corruption, intermittent bugs that are hard to reproduce.

**Remedy**: Use synchronization primitives, atomic operations, or redesign to avoid shared mutable state.

### Resource Leaks

**Symptom**: Files, connections, handles, or locks acquired but not released on all code paths (especially error paths).

**Risk**: Resource exhaustion, connection pool depletion, deadlocks.

**Remedy**: Use language idioms for guaranteed cleanup (try-finally, defer, using, context managers).

## Security Anti-Patterns

### String-Concatenated Queries

**Symptom**: SQL, NoSQL, or LDAP queries built by concatenating user input into the query string.

**Risk**: Injection attacks allowing unauthorized data access or modification.

**Remedy**: Use parameterized queries or prepared statements exclusively.

### Unescaped Output

**Symptom**: User-provided data rendered in HTML, JavaScript, or other output without escaping or sanitization.

**Risk**: Cross-site scripting (XSS) allowing session hijacking or data theft.

**Remedy**: Use the framework's auto-escaping. Escape manually where auto-escaping is not available. Set Content-Security-Policy headers.

### Hard-Coded Secrets

**Symptom**: API keys, passwords, tokens, or connection strings embedded directly in source code.

**Risk**: Credential exposure through version control, logs, or compiled artifacts.

**Remedy**: Use environment variables, secret managers, or configuration files excluded from version control.

### Path Traversal

**Symptom**: File paths constructed from user input without normalization or validation.

**Risk**: Unauthorized file access outside the intended directory.

**Remedy**: Normalize paths, reject `..` sequences, and validate the resolved path is within the expected base directory.

### Overly Permissive Error Messages

**Symptom**: Error responses that expose internal details: stack traces, database schemas, file paths, or server configuration.

**Risk**: Information leakage that assists attackers in crafting targeted attacks.

**Remedy**: Return generic error messages to users. Log detailed information server-side only.

## Maintainability Anti-Patterns

### God Function / God Class

**Symptom**: A single function or class that handles many unrelated responsibilities. Hundreds of lines. Multiple levels of nesting.

**Risk**: Difficult to understand, test, and modify. Changes have unpredictable side effects.

**Remedy**: Extract cohesive groups of logic into focused functions or classes, each with a single responsibility.

### Premature Abstraction

**Symptom**: Interfaces, base classes, factories, or strategy patterns created for a single implementation. "Just in case" extension points.

**Risk**: Added complexity without benefit. Harder to understand and navigate. Often the abstraction boundary is wrong and must be rewritten later.

**Remedy**: Wait for at least two concrete use cases before abstracting. Three similar lines of code are better than a premature abstraction.

### Deep Nesting

**Symptom**: Code with 4+ levels of indentation from nested conditionals, loops, or callbacks.

**Risk**: Hard to follow control flow. Easy to introduce bugs in deeply nested branches.

**Remedy**: Use early returns, guard clauses, extract helper functions, or restructure with pattern matching.

### Dead Code

**Symptom**: Unreachable code, unused variables, commented-out blocks, functions that are never called.

**Risk**: Confuses readers about what the code actually does. May hide bugs.

**Remedy**: Delete dead code. Version control preserves history if it is needed later.

### Inconsistent Naming

**Symptom**: The same concept referred to by different names in different places. Mixed naming styles within the same scope.

**Risk**: Readers cannot tell if different names refer to the same thing or different things.

**Remedy**: Choose one term per concept and use it consistently. Follow the project's established vocabulary.

### Circular Dependencies

**Symptom**: Module A imports Module B, which imports Module A (directly or through a chain).

**Risk**: Initialization order problems, tight coupling, difficulty understanding the dependency graph.

**Remedy**: Extract the shared concern into a third module. Invert the dependency with an interface or callback.

## Performance Anti-Patterns

### N+1 Queries

**Symptom**: One query to fetch a list, then one query per item to fetch related data, inside a loop.

**Risk**: Linear growth in database round trips. Severe performance degradation at scale.

**Remedy**: Use joins, eager loading, batch queries, or data loader patterns.

### Unbounded Collection Growth

**Symptom**: Collections (lists, maps, caches) that grow without limit. No eviction, expiration, or size cap.

**Risk**: Memory exhaustion over time (memory leak).

**Remedy**: Define maximum size. Implement eviction strategy (LRU, TTL). Use weak references where appropriate.

### Redundant Computation in Loops

**Symptom**: Expensive operations repeated on every iteration when the result does not change.

**Risk**: Wasted CPU time proportional to loop iterations.

**Remedy**: Hoist invariant computation out of the loop. Cache results that are reused.

### Synchronous Blocking in Async Code

**Symptom**: Blocking I/O calls inside async functions or event loops. Thread.sleep in request handlers.

**Risk**: Blocks the event loop or thread pool, degrading throughput for all requests.

**Remedy**: Use async I/O operations. Move blocking work to a dedicated thread pool.

## File Structure Anti-Patterns

### Mega File

**Symptom**: A single file with 500+ lines containing multiple unrelated components, functions, or classes.

**Risk**: Hard to navigate, understand, and modify. Merge conflicts become frequent.

**Remedy**: Split by cohesion — group code that changes together into separate files.

### Deeply Nested Directories

**Symptom**: Directory hierarchy with 5+ levels of nesting. Long import paths.

**Risk**: Difficult navigation. Overly specific categorization that becomes brittle as the codebase evolves.

**Remedy**: Flatten to 3-4 levels. Merge directories with only one child. Let the structure evolve with the codebase rather than pre-organizing.

### Scattered Concerns

**Symptom**: Related files spread across distant directories. A feature's model, view, controller, test, and types are all in different directory trees.

**Risk**: Making a single change requires editing files in many locations. Easy to miss a file.

**Remedy**: Colocate related files. Place tests, types, and styles alongside the code they relate to.

### Empty Wrapper Directories

**Symptom**: Directories containing only one subdirectory, creating unnecessary nesting (e.g., `src/modules/core/lib/utils/`).

**Risk**: Adds path length and navigation steps without organizational benefit.

**Remedy**: Merge or remove intermediate directories that add no semantic value.

### Framework Convention Violation

**Symptom**: Files placed outside the directories the framework expects. Custom directory names used instead of framework-prescribed ones. Framework's file-based routing, auto-loading, or auto-discovery is broken by non-standard placement.

**How to detect**: Identify the framework from the project's manifest/config files. Compare the file placement against the framework's documented project layout and against the placement of existing files of the same type in the project.

**Risk**: Framework features silently stop working (routing, auto-loading, hot reload). Developers familiar with the framework cannot find files where they expect them. Framework upgrades may break custom structures.

**Remedy**: Identify the framework and version in use. Check the existing project structure and the framework's official documentation for the expected layout. Move files to the prescribed locations. When the framework has no strict convention, follow the project's established pattern consistently.

### Technology-Only Organization

**Symptom**: Top-level directories named only by technical role (`models/`, `views/`, `controllers/`, `helpers/`, `utils/`) in a project large enough to warrant domain separation.

**Risk**: Adding a feature requires touching many directories. Hard to understand what the application does from the file tree.

**Remedy**: Organize by feature or domain at the top level. Use technical layers within each feature if needed.
