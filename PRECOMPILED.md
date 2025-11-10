# Precompiled Binaries Guide

Nosnos supports precompiled NIFs to avoid requiring Zig compiler installation for end users.

## For Library Users

If precompiled binaries are available for your platform, they will be automatically downloaded and used. No Zig compiler installation required!

### Supported Platforms

- Linux (x86_64, aarch64, arm) - GNU and musl libc
- macOS (x86_64, aarch64/Apple Silicon)
- FreeBSD (x86_64, aarch64)

### Force Recompilation

To compile from source instead of using precompiled binaries:

```bash
export ZIGLER_PRECOMPILE_FORCE_RECOMPILE=1
mix deps.compile nosnos --force
```

### Force Reload

To force reload the precompiled binary (e.g., after updating):

```bash
export ZIGLER_PRECOMPILE_FORCE_RELOAD=1
mix deps.compile nosnos --force
```

## For Library Maintainers

### Building Precompiled Binaries

1. **Build locally for your platform:**

```bash
./scripts/build_precompiled.sh 0.2.0
```

This will:
- Build the NIF for your current platform
- Generate SHA256 checksum
- Output the checksum to add to `mix.exs`

2. **Build for multiple platforms using GitHub Actions:**

Create a new release tag:

```bash
git tag v0.2.0
git push origin v0.2.0
```

The GitHub Actions workflow (`.github/workflows/precompile.yml`) will:
- Build NIFs for all supported platforms
- Generate SHA256 checksums
- Create a GitHub Release with all binaries
- Attach a `CHECKSUMS.txt` file with all hashes

3. **Update mix.exs with checksums:**

After the release is built, copy the checksums from the release's `CHECKSUMS.txt` file and add them to `@shasum` in `mix.exs`:

```elixir
@shasum [
  "x86_64-linux-gnu": "abc123...",
  "aarch64-linux-gnu": "def456...",
  # ... other platforms
]
```

4. **Enable precompiled binaries in lib/nosnos.ex:**

Uncomment the precompiled option:

```elixir
use Zig,
  otp_app: :nosnos,
  precompiled: {:web, @lib_address, @shasum}
```

5. **Commit and release:**

```bash
git add mix.exs lib/nosnos.ex
git commit -m ":sparkles: Enable precompiled binaries"
git push
mix hex.publish
```

### Manual Release Process

If you need to build and release manually:

1. Build for current platform:
   ```bash
   ./scripts/build_precompiled.sh 0.2.0
   ```

2. Cross-compile for other platforms (requires Docker/QEMU):
   ```bash
   # Example for aarch64 Linux
   docker run --rm -v $(pwd):/workspace -w /workspace \
     elixir:1.18-alpine sh -c "
     apk add zig && \
     mix local.hex --force && \
     mix local.rebar --force && \
     ./scripts/build_precompiled.sh 0.2.0
   "
   ```

3. Upload binaries to GitHub Release manually

4. Update checksums in `mix.exs`

## Architecture

### URL Template

Precompiled binaries are downloaded from:

```
https://github.com/Comamoca/nosnos/releases/download/v{VERSION}/nosnos.{VERSION}.{TRIPLE}.{EXT}
```

Where:
- `{VERSION}` - Release version (e.g., `0.2.0`)
- `{TRIPLE}` - Platform triple (e.g., `x86_64-linux-gnu`)
- `{EXT}` - File extension (`.so` on Unix, `.dll` on Windows)

### Platform Triples

Format: `{ARCH}-{OS}-{ABI}`

Examples:
- `x86_64-linux-gnu` - x86_64 Linux with GNU libc
- `aarch64-macos-none` - Apple Silicon macOS
- `x86_64-linux-musl` - x86_64 Linux with musl libc

### SHA256 Verification

Each binary is verified against its SHA256 checksum before use. This ensures:
- Binary integrity
- Protection against tampering
- Reproducible builds

## Troubleshooting

### "No precompiled binary available for your platform"

Your platform might not be supported yet. You can:

1. Compile from source (Zig compiler required):
   ```bash
   export ZIGLER_PRECOMPILE_FORCE_RECOMPILE=1
   mix deps.compile nosnos --force
   ```

2. Request support for your platform by opening an issue

### "SHA256 mismatch"

The downloaded binary doesn't match the expected checksum. This could indicate:
- Corrupted download
- Network issue
- Security concern

Try:
```bash
export ZIGLER_PRECOMPILE_FORCE_RELOAD=1
mix deps.compile nosnos --force
```

If the issue persists, please report it.

### Build errors with precompiled binaries

Force recompilation from source:

```bash
export ZIGLER_PRECOMPILE_FORCE_RECOMPILE=1
mix clean
mix deps.compile nosnos --force
```

## Security Considerations

- All binaries are built in GitHub Actions with public logs
- SHA256 checksums are embedded in the source code
- Binaries are served from GitHub Releases (HTTPS only)
- Users can always choose to compile from source
- Checksums are verified before loading the NIF

## Resources

- [Zigler Precompiled Documentation](https://hexdocs.pm/zigler/precompiled.html)
- [GitHub Actions Workflow](.github/workflows/precompile.yml)
- [Build Script](scripts/build_precompiled.sh)
