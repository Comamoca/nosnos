# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nosnos is an Elixir library implementing Nostr protocol cryptographic operations using Zig for performance-critical code. The project uses Zigler to integrate Zig NIFs (Native Implemented Functions) with Elixir.

**Key Technologies:**
- Elixir 1.18+ with Mix build system
- Zig 0.15.2 for cryptographic implementations
- Zigler ~> 0.15.1 for Elixir-Zig integration
- Nix flakes for reproducible development environment

## Development Environment

### Setup with Nix (Recommended)

```bash
# Enter development shell (uses devenv)
nix develop

# Or with direnv (if .envrc configured)
direnv allow
```

The Nix environment provides:
- Elixir with language server
- Zig 0.15.2 toolchain
- Pre-commit hooks (treefmt, ripsecrets, git-secrets)

### Manual Setup

```bash
# Install Elixir dependencies
mix deps.get

# Get Zig compiler (if not using Nix)
mix zig.get
```

## Common Commands

### Building and Testing

```bash
# Compile the project (includes Zig NIFs)
mix compile

# Run all tests
mix test

# Run specific test file
mix test test/nosnos_test.exs

# Run tests in Zig code
zig test schnorr.zig
```

### Formatting

```bash
# Format Elixir code
mix format

# Format with Nix tooling
nix fmt
```

### Development Workflow

```bash
# Start interactive shell with project loaded
iex -S mix

# Clean build artifacts
mix clean

# Clean and rebuild (useful after Zig changes)
mix clean && mix compile
```

## Architecture

### Cryptographic Core (schnorr.zig)

The main Zig implementation in `schnorr.zig` provides Nostr event signing and verification using BIP-340 Schnorr signatures:

**Core Functions:**
- `getPublicKey(secret_key)` - Derives secp256k1 public key from private key
- `sign(secret_key, msg)` - Creates BIP-340 Schnorr signature
- `verify(public_key, msg, signature)` - Verifies BIP-340 signature
- `sign_event(allocator, secret_key, created_at, kind, tags, content)` - Signs complete Nostr events
- `verify_event(allocator, event)` - Verifies Nostr event signatures
- `calculateEventId(allocator, pubkey, created_at, kind, tags, content)` - Computes Nostr event ID

**Data Structures:**
- `Event` struct - Represents Nostr events with id, pubkey, created_at, kind, content, sig, and tags

**Implementation Details:**
- Uses `std.crypto.ecc.Secp256k1` for elliptic curve operations
- BIP-340 tagged hashing with "BIP0340/challenge" tag
- Event ID calculation follows NIP-01 specification (JSON serialization + SHA256)
- Auxiliary randomness in signing (currently uses zero for deterministic testing)

### Elixir Integration (lib/nosnos.ex)

Currently a skeleton module. Will integrate Zig functions using Zigler's `use Zig` macro and `~Z` sigils.

**Expected Integration Pattern:**
```elixir
defmodule Nosnos do
  use Zig, otp_app: :nosnos

  ~Z"""
  // Zig code from schnorr.zig
  """
end
```

### Memory Management

When integrating Zig code with Zigler:
- **Always use `beam.allocator`** for memory allocation in Zig NIFs
- Avoid `std.heap.page_allocator` - it's not tracked by BEAM GC
- Use `defer` and `errdefer` for cleanup in error paths
- The BEAM VM automatically manages memory returned to Elixir

### Type Marshalling (Elixir ↔ Zig)

**Current schnorr.zig types to consider:**
- `[32]u8` arrays → Elixir binaries (for keys, hashes, signatures)
- `[]u8` slices → Elixir binaries or lists
- `i64` → Elixir integers (for timestamps)
- `Event` struct → Elixir maps with atom keys

**Recommended Zigler Configuration:**
```elixir
use Zig,
  otp_app: :nosnos,
  nifs: [
    # Configure binary returns for byte arrays
    get_public_key: [return: :binary],
    sign: [return: :binary]
  ]
```

## Integration Guidance

### Moving schnorr.zig to Zigler NIFs

When integrating the standalone Zig code into Elixir:

1. **Wrap with Zigler module** - Use `use Zig` in Elixir module
2. **Adapt allocator** - Change allocations to use `beam.allocator`
3. **Handle errors** - Zig errors automatically become `ErlangError` in Elixir
4. **Convert types** - Use `beam.make()` for complex return types like Event structs
5. **Mark exports** - Only `pub fn` functions become Elixir-callable NIFs

### Concurrency Considerations

**For cryptographic operations:**
- Signing/verification are CPU-bound - use `:dirty_cpu` mode for production
- Quick key derivation can use synchronous mode (< 1ms)

```elixir
use Zig,
  otp_app: :nosnos,
  nifs: [
    sign_event: [:dirty_cpu],
    verify_event: [:dirty_cpu]
  ]
```

## Testing Strategy

### Zig Tests
- Comprehensive tests exist in `schnorr.zig` (lines 233-420)
- Run with `zig test schnorr.zig`
- Include: key generation, signing, verification, event serialization
- Test vectors include real Nostr events

### Elixir Tests
- Located in `test/nosnos_test.exs`
- Currently skeletal - expand when Zig integration is complete
- Should mirror Zig test coverage for NIFs

**Recommended test additions:**
```elixir
# Test error handling
test "validates invalid signatures" do
  assert_raise ErlangError, fn ->
    Nosnos.verify_event(invalid_event)
  end
end

# Test type marshalling
test "handles binary keys correctly" do
  pubkey = Nosnos.get_public_key(secret_key)
  assert is_binary(pubkey) and byte_size(pubkey) == 32
end
```

## Nostr Protocol Implementation Notes

This library implements:
- **NIP-01**: Basic event structure, signing, and verification
- **BIP-340**: Schnorr signatures over secp256k1 curve

**Event ID Calculation:**
```
event_id = SHA256(JSON.stringify([
  0,                    # reserved for future use
  <pubkey>,            # hex string
  <created_at>,        # unix timestamp
  <kind>,              # integer
  <tags>,              # array of arrays
  <content>            # string
]))
```

**Signature Scheme:**
- BIP-340 Schnorr over secp256k1
- Deterministic nonce generation from tagged hash
- Y-coordinate parity handling (even Y-coordinates only)

## Security Considerations

**When working with cryptographic code:**
- Never log or print private keys
- The implementation uses `std.crypto.random.bytes()` for secure aux_rand generation
- Validate all inputs before cryptographic operations
- Consider timing attack resistance for production deployments

**Pre-commit Hooks:**
The Nix environment enables hooks to prevent secret leakage:
- `git-secrets` - Scans for credentials
- `ripsecrets` - Additional secret detection

## Build Artifacts

**Generated during compilation:**
- `_build/` - Elixir compilation output
- `.devenv/`, `.direnv/` - Nix environment artifacts (gitignored)
- Zigler generates Zig build files in `_build/` directory

**Clean builds:**
```bash
mix clean        # Clean Elixir artifacts
rm -rf _build    # Full clean including Zig NIFs
```
