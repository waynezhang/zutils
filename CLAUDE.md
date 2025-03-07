# ZUTILS DEVELOPMENT GUIDE

## Build & Test Commands
```bash
# Build the library
zig build

# Run all tests
zig build test

# Formats all code
zig fmt src/

# Build with optimization
zig build -Doptimize=ReleaseSafe  # Options: Debug, ReleaseSmall, ReleaseFast
```

## Code Style Guidelines
- **Naming**: functions=camelCase, variables=snake_case, types=PascalCase
- **Memory**: Functions with "Alloc" suffix allocate memory caller must free
- **Errors**: Functions that can fail return errors with `!` syntax
- **Documentation**: Use `///` before function definitions
- **Tests**: Each utility function should have corresponding tests
- **Platform-specific code**: Use `@import("builtin").target.os.tag`

## Project Structure
- `src/`: Core library files for different utilities (fs, gzip, http, log, net)
- `scripts/`: Helper scripts for development
- `testdata/`: Files used for testing