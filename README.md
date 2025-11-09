<div align="center">

# Nosnos

🔐 High-performance Nostr cryptographic operations library for Elixir

![Last commit](https://img.shields.io/github/last-commit/Comamoca/nosnos?style=flat-square)
![Issues](https://img.shields.io/github/issues/Comamoca/nosnos?style=flat-square)
![License](https://img.shields.io/github/license/Comamoca/nosnos?style=flat-square)
![Stars](https://img.shields.io/github/stars/Comamoca/nosnos?style=flat-square)

</div>

<img src="https://emoji2svg.deno.dev/api/⚡" alt="eyecatch" height="100">

## 🔥 Features

Nosnos is a Elixir library implementing **BIP-340 Schnorr signatures** and **Nostr protocol (NIP-01)** cryptographic operations using Zig NIFs.

## 🚀 How to use

### Basic Signing and Verification

```elixir
# Generate a random secret key (32 bytes)
secret_key = :crypto.strong_rand_bytes(32)

# Derive the public key
public_key = Nosnos.get_public_key(secret_key)

# Sign a message
message = "Hello Nostr!"
message_hash = :crypto.hash(:sha256, message)
signature = Nosnos.sign(secret_key, message_hash)

# Verify the signature
is_valid = Nosnos.verify(public_key, message_hash, signature)
```

### Nostr Event Operations

```elixir
# Sign a Nostr event
secret_key = :crypto.strong_rand_bytes(32)
timestamp = :os.system_time(:second)
content = "Hello from Elixir!"
tags = "[]"  # JSON string

event = Nosnos.sign_event(secret_key, timestamp, 1, tags, content)
# => %{
#   id: "356faddb...",
#   pubkey: "132fc0db...",
#   created_at: 1700000000,
#   kind: 1,
#   tags: "[]",
#   content: "Hello from Elixir!",
#   sig: "fb8f88a9..."
# }

# Verify a Nostr event
is_valid = Nosnos.verify_event(event)
```

## ⬇️ Install

### Prerequisites

- Elixir 1.18 or later
- Zig 0.15.2 (automatically managed by Zigler)

### Add to your project

Add `nosnos` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nosnos, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
mix compile
```

### From source

```bash
git clone https://github.com/Comamoca/nosnos.git
cd nosnos
mix deps.get
mix test
```

## ⛏️ Development

### Using Nix (Recommended)

This project uses Nix flakes for reproducible development environments:

```bash
# Enter the development shell
nix develop

# Or use direnv (if .envrc is configured)
direnv allow
```

The Nix environment includes:
- Elixir with language server
- Zig 0.15.2 toolchain
- Pre-commit hooks (treefmt, ripsecrets, git-secrets)

### Manual Setup

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Format code
mix format
```

## 📜 License

MIT License

## 💕 Special Thanks

- [**Zigler**](https://github.com/E-xyza/zigler) - Seamless Zig integration for Elixir
- [**Zig Standard Library**](https://ziglang.org/documentation/master/std/) - Excellent cryptography primitives
- [**Nostr Protocol**](https://github.com/nostr-protocol/nostr) - Decentralized social networking protocol
- [**vitalnodo/bip340**](https://github.com/vitalnodo/bip340) - Zig BIP-340 reference implementation
- All contributors and testers
