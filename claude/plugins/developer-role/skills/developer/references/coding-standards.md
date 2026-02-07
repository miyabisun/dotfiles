# Coding Standards

Comprehensive coding standards for producing clean, maintainable, and consistent code across any programming language.

## Naming Conventions

### General Rules

- Use names that reveal intent: a reader should understand the purpose without additional context
- Avoid abbreviations unless they are universally understood (e.g., `id`, `url`, `http`)
- Avoid single-letter names except for loop counters (`i`, `j`, `k`) or lambda parameters in short expressions
- Be consistent with the naming style already used in the codebase

### Naming by Context

| Element         | Style Guideline                                                    |
| --------------- | ------------------------------------------------------------------ |
| Variables       | Describe what the value represents, not its type                   |
| Functions       | Start with a verb describing what the function does                |
| Booleans        | Use `is`, `has`, `can`, `should` prefixes to indicate boolean nature |
| Constants       | Use UPPER_SNAKE_CASE or follow the language convention             |
| Classes/Types   | Use nouns describing what the entity represents                    |
| Interfaces      | Describe the capability or contract, not the implementation        |
| Files/Modules   | Reflect the primary export or responsibility                       |

### Naming Anti-Patterns

- `data`, `info`, `item`, `thing` — too generic, add specificity
- `temp`, `tmp`, `x` — acceptable only in very limited scope
- `handleClick`, `processData` — acceptable but prefer more specific names like `submitForm`, `parseUserInput`
- Numbered suffixes (`user1`, `user2`) — use meaningful differentiators

## Code Structure

### Functions

- Each function should do one thing and do it well
- Keep functions short enough to understand at a glance (typically under 30 lines)
- Limit parameters to 3-4; use an options object or configuration struct for more
- Avoid side effects where possible; clearly document side effects where necessary
- Return early to avoid deep nesting

### Modules and Files

- One primary responsibility per file
- Group related functions and types together
- Keep imports/dependencies at the top, organized logically
- Separate public API from internal implementation

### File Splitting

Split a file into multiple files when any of these conditions apply:

- **Size**: The file exceeds approximately 300 lines (language-dependent; use the project's norms as a guide)
- **Multiple responsibilities**: The file contains unrelated concerns that change for different reasons
- **Reuse**: A section of code is imported or referenced from multiple places
- **Cognitive load**: A developer must scroll extensively to understand the file's purpose

When splitting, extract by **cohesion** — group code that changes together. Avoid splitting purely by code type (e.g., separating all constants into a `constants` file) unless the project already follows that convention.

**Do not split** when:
- The file is small and cohesive
- Splitting would create files with only a few lines and no standalone purpose
- The pieces have tight circular dependencies that would make the split awkward

### Directory Structure

#### Principles

- **Mirror the domain, not the technology**: Organize by feature or domain concept (e.g., `auth/`, `billing/`, `users/`) rather than by technical layer (e.g., `controllers/`, `models/`, `views/`) unless the framework mandates otherwise
- **Follow existing conventions first**: If the project already has a directory structure, extend it consistently rather than introducing a new pattern
- **Limit nesting depth**: Keep directory hierarchies to 3-4 levels deep. Deeper nesting makes navigation harder and paths longer
- **Colocate related files**: Place tests, styles, and types alongside the code they relate to when the framework supports it

#### When to Create a New Directory

- A group of 3+ related files emerges that share a distinct purpose
- A feature or module has its own internal structure (types, utilities, tests)
- Separating a concern would clarify the project's architecture

#### When NOT to Create a New Directory

- For a single file — a flat structure is simpler
- For organizational symmetry alone — do not create empty or near-empty directories
- When it would break the project's existing conventions

#### Common Patterns

| Pattern | When to Use |
|---------|-------------|
| **Feature-based** (`features/auth/`, `features/billing/`) | Applications with distinct domain areas |
| **Layer-based** (`controllers/`, `services/`, `repositories/`) | When the framework expects this (e.g., Rails, Spring) |
| **Hybrid** (features at top level, layers within each feature) | Large applications needing both domain and technical separation |
| **Flat** (all files in one directory) | Small projects or modules with few files |

#### Framework Convention Compliance

When working within a framework, its directory conventions take precedence over all general principles in this document. Before creating or moving files, identify and follow the framework's prescribed structure.

**Detection — Identify the framework:**

1. Read the project's manifest and configuration files (`package.json`, `Gemfile`, `build.gradle`, `composer.json`, `pyproject.toml`, `pubspec.yaml`, `Cargo.toml`, etc.)
2. Note the framework name and version — conventions often differ between major versions (e.g., Next.js App Router vs Pages Router)

**Investigation — Learn the conventions:**

1. Examine the project's existing directory structure to understand the patterns already in use
2. If the convention is unclear from the existing structure, look up the framework's official project layout documentation
3. If the framework provides a scaffolding CLI (e.g., `generate`, `create`, `make`, `new`), check where it places generated files — this is the canonical location

**Application — Follow the conventions:**

- **Never fight the framework** — If it prescribes a directory for a file type, use that directory even if it conflicts with general best practices
- **Use framework-idiomatic names** — If the framework expects `middleware/`, do not rename it to `interceptors/` even if another name seems clearer
- **Respect special directories** — Many frameworks assign meaning to specific directory names (routing from file paths, auto-loading from directory names, static asset serving). Placing files outside these directories silently breaks functionality
- **Match existing placement** — When adding a new file of a type that already exists in the project, place it alongside similar files

#### Naming Directories

- Use lowercase with hyphens (`user-management`) or the project's convention
- Name directories after the concept they contain, not what type of files are inside
- Avoid generic names like `utils/`, `helpers/`, `misc/` — if a utility is used by one module, colocate it; if shared broadly, name the directory after its purpose (e.g., `string-formatting/`, `date-helpers/`)

### Control Flow

- Prefer early returns over nested conditionals
- Avoid deep nesting (more than 3 levels indicates need for extraction)
- Use guard clauses to handle edge cases at the top of functions
- Prefer `switch`/`match` over long `if-else` chains when matching discrete values

## Formatting

- Follow the existing formatting style in the project
- If a formatter (Prettier, Black, gofmt, etc.) is configured, use it
- Do not reformat code unrelated to the current change
- Use consistent indentation (spaces or tabs as the project dictates)

## Comments and Documentation

### When to Comment

- Explain **why**, not **what** — the code shows what, comments explain why
- Document non-obvious business logic or domain-specific rules
- Note workarounds with links to issues or external references
- Mark intentional decisions that might look like mistakes

### When NOT to Comment

- Do not comment obvious code (`i++ // increment i`)
- Do not leave commented-out code — delete it (version control preserves history)
- Do not add redundant docstrings that repeat the function name
- Do not add TODO comments without a tracking issue or clear next step

## Error Handling

### Principles

- Handle errors at system boundaries (user input, external APIs, file I/O)
- Trust internal code and framework guarantees — do not over-validate
- Fail fast with clear error messages for unexpected states
- Propagate errors with context — wrap errors to add information about where they occurred

### Patterns

- Use the language's idiomatic error handling (exceptions, Result types, error returns)
- Avoid catching generic exceptions unless at the top level
- Never silently swallow errors
- Log errors with sufficient context for debugging (what happened, what was expected, relevant state)

## Design Patterns

### Prefer

- **Composition over inheritance** — build complex behavior from simple, reusable parts
- **Dependency injection** — pass dependencies rather than constructing them internally
- **Immutability** — prefer immutable data structures where the language supports them
- **Interface segregation** — small, focused interfaces over large, general ones

### Avoid

- **Premature abstraction** — do not create interfaces, base classes, or factories until there are at least two concrete use cases
- **God objects** — classes that know or do too much
- **Singletons** — prefer explicit dependency passing
- **Magic values** — use named constants or enums instead of literal values with special meaning

## Language-Specific Conventions

When working in a specific language, follow its established conventions:

- **Python**: PEP 8 style, type hints for public APIs, docstrings for public functions
- **JavaScript/TypeScript**: Prefer `const`, use strict equality, follow Airbnb or project's ESLint config
- **Go**: Follow Effective Go, `gofmt`, exported names are capitalized
- **Rust**: Follow Rust API Guidelines, use `clippy` suggestions
- **Java**: Follow Google Java Style or project's checkstyle config
- **C#**: Follow Microsoft's naming guidelines, PascalCase for public members

Always prioritize the project's existing conventions over general language guidelines.
