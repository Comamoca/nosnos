defmodule Nosnos do
  @moduledoc """
  Nostr protocol cryptographic operations using Zig for performance-critical code.

  This module provides BIP-340 Schnorr signature operations and Nostr event
  signing/verification through Zig NIFs (Native Implemented Functions).

  ## Features

  - Derive secp256k1 public keys from private keys
  - Sign and verify BIP-340 Schnorr signatures
  - Sign and verify complete Nostr events (NIP-01)
  - Calculate Nostr event IDs

  ## Security Considerations

  - Never log or expose private keys
  - The implementation uses cryptographically secure random generation for aux_rand
  - Signatures are non-deterministic for enhanced security against side-channel attacks
  """

  use Zig,
    otp_app: :nosnos

  ~Z"""
  const std = @import("std");
  const beam = @import("beam");

  const Secp256k1 = std.crypto.ecc.Secp256k1;
  const Scalar = Secp256k1.scalar.Scalar;
  const Sha256 = std.crypto.hash.sha2.Sha256;

  // https://github.com/vitalnodo/bip340/blob/main/bip340.zig
  fn taggedHash(tag: []const u8, msg: []const u8) [32]u8 {
      var buf: [32]u8 = undefined;
      Sha256.hash(tag, &buf, .{});

      var sha256 = Sha256.init(.{});
      sha256.update(buf[0..]);
      sha256.update(buf[0..]);
      sha256.update(msg);
      sha256.final(&buf);
      return buf;
  }

  /// Derives a secp256k1 public key from a 32-byte secret key.
  /// Returns the X coordinate of the public key point (32 bytes).
  pub fn get_public_key(secret_key: [32]u8) ![32]u8 {
      const sk = try Scalar.fromBytes(secret_key, .big);
      const P = try Secp256k1.basePoint.mul(sk.toBytes(.big), .big);
      const coords = P.affineCoordinates();
      return coords.x.toBytes(.big);
  }

  /// Signs a 32-byte message using BIP-340 Schnorr signature scheme.
  /// Returns a 64-byte signature (R || s).
  pub fn sign(secret_key: [32]u8, msg: [32]u8) ![64]u8 {
      const sk_scalar = try Scalar.fromBytes(secret_key, .big);
      const P = try Secp256k1.basePoint.mul(sk_scalar.toBytes(.big), .big);
      const P_coords = P.affineCoordinates();

      // d' = sk if P.y is even, else n - sk
      const d = if (P_coords.y.isOdd()) sk_scalar.neg() else sk_scalar;

      const public_key = P_coords.x.toBytes(.big);

      // Auxiliary randomness using secure random generation
      var aux_rand: [32]u8 = undefined;
      std.crypto.random.bytes(&aux_rand);

      // t = d ^ H(aux_rand)
      var aux_hash: [32]u8 = undefined;
      Sha256.hash(&aux_rand, &aux_hash, .{});

      var t: [32]u8 = undefined;
      for (0..32) |i| {
          t[i] = secret_key[i] ^ aux_hash[i];
      }

      // rand = H(t || P || m)
      var rand_hash: [32]u8 = undefined;
      var sha256 = Sha256.init(.{});
      sha256.update(&t);
      sha256.update(&public_key);
      sha256.update(&msg);
      sha256.final(&rand_hash);

      const k = try Scalar.fromBytes(rand_hash, .big);

      // R = k*G
      const R = try Secp256k1.basePoint.mul(k.toBytes(.big), .big);
      const R_coords = R.affineCoordinates();
      const r_bytes = R_coords.x.toBytes(.big);

      // k' = k if R.y is even, else n - k
      const k_final = if (R_coords.y.isOdd()) k.neg() else k;

      // e = H(R.x || P.x || m)
      var to_hash: [96]u8 = undefined;
      @memcpy(to_hash[0..32], &r_bytes);
      @memcpy(to_hash[32..64], &public_key);
      @memcpy(to_hash[64..96], &msg);
      const e = try Scalar.fromBytes(
          taggedHash("BIP0340/challenge", &to_hash),
          .big,
      );

      // s = k' + e*d
      const s = k_final.add(e.mul(d));

      var signature: [64]u8 = undefined;
      @memcpy(signature[0..32], &r_bytes);
      @memcpy(signature[32..64], &s.toBytes(.big));

      return signature;
  }

  /// Verifies a BIP-340 Schnorr signature.
  /// Returns true if the signature is valid, false otherwise.
  pub fn verify(public_key: [32]u8, msg: [32]u8, signature: [64]u8) !bool {
      const Px = try Secp256k1.Fe.fromBytes(public_key, .big);
      const Py = try Secp256k1.recoverY(Px, false);
      const P = try Secp256k1.fromAffineCoordinates(.{ .x = Px, .y = Py });
      const r = try Secp256k1.Fe.fromBytes(signature[0..32].*, .big);
      const s = try Secp256k1.scalar.Scalar.fromBytes(signature[32..64].*, .big);
      var to_hash: [96]u8 = undefined;
      @memcpy(to_hash[0..32], signature[0..32]);
      @memcpy(to_hash[32..64], public_key[0..]);
      @memcpy(to_hash[64..96], msg[0..]);
      const e = try Scalar.fromBytes(
          taggedHash("BIP0340/challenge", to_hash[0..]),
          .big,
      );
      const R = (try Secp256k1.basePoint.mulPublic(
          s.toBytes(.big),
          .big,
      )).sub(try P.mul(e.toBytes(.big), .big));
      if (R.affineCoordinates().y.isOdd()) {
          return false;
      }
      if (!R.affineCoordinates().x.equivalent(r)) {
          return false;
      }
      return true;
  }

  /// Calculates a Nostr event ID from event components.
  /// Returns a 32-byte SHA256 hash of the serialized event.
  pub fn calculate_event_id(pubkey: []const u8, created_at: i64, kind: i64, tags: []const u8, content: []const u8) ![32]u8 {
      const allocator = beam.allocator;

      // Manually construct the JSON string since we need specific formatting
      // Format: [0,"<pubkey>",<created_at>,<kind>,<tags>,"<content>"]
      var buf = try std.ArrayList(u8).initCapacity(allocator, 256);
      defer buf.deinit(allocator);

      try buf.appendSlice(allocator, "[0,\"");
      try buf.appendSlice(allocator, pubkey);
      try buf.appendSlice(allocator, "\",");
      try buf.writer(allocator).print("{d}", .{created_at});
      try buf.appendSlice(allocator, ",");
      try buf.writer(allocator).print("{d}", .{kind});
      try buf.appendSlice(allocator, ",");
      try buf.appendSlice(allocator, tags);
      try buf.appendSlice(allocator, ",\"");

      // Escape content string for JSON
      for (content) |c| {
          if (c == '"') {
              try buf.appendSlice(allocator, "\\\"");
          } else if (c == '\\') {
              try buf.appendSlice(allocator, "\\\\");
          } else if (c == '\n') {
              try buf.appendSlice(allocator, "\\n");
          } else if (c == '\r') {
              try buf.appendSlice(allocator, "\\r");
          } else if (c == '\t') {
              try buf.appendSlice(allocator, "\\t");
          } else {
              try buf.append(allocator, c);
          }
      }

      try buf.appendSlice(allocator, "\"]");

      const serialized = buf.items;

      var id: [32]u8 = undefined;
      var sha256 = Sha256.init(.{});
      sha256.update(serialized);
      sha256.final(&id);

      return id;
  }

  /// Signs a complete Nostr event and returns all event fields.
  /// Returns a map with keys: id, pubkey, created_at, kind, tags, content, sig.
  pub fn sign_event(secret_key: [32]u8, created_at: i64, kind: i64, tags: []const u8, content: []const u8) !beam.term {
      const public_key_bytes = try get_public_key(secret_key);

      // Convert public key to hex
      var pubkey_hex: [64]u8 = undefined;
      _ = try std.fmt.bufPrint(&pubkey_hex, "{s}", .{std.fmt.bytesToHex(&public_key_bytes, .lower)});

      const pubkey_str = pubkey_hex[0..];

      // Calculate event ID
      const event_id = try calculate_event_id(pubkey_str, created_at, kind, tags, content);

      // Sign the event ID
      const signature = try sign(secret_key, event_id);

      // Convert signature to hex
      var sig_hex: [128]u8 = undefined;
      _ = try std.fmt.bufPrint(&sig_hex, "{s}", .{std.fmt.bytesToHex(&signature, .lower)});

      // Convert event ID to hex
      var id_hex: [64]u8 = undefined;
      _ = try std.fmt.bufPrint(&id_hex, "{s}", .{std.fmt.bytesToHex(&event_id, .lower)});

      // Create Elixir map
      return beam.make(.{
          .id = id_hex[0..],
          .pubkey = pubkey_str,
          .created_at = created_at,
          .kind = kind,
          .tags = tags,
          .content = content,
          .sig = sig_hex[0..],
      }, .{});
  }

  /// Verifies a Nostr event signature.
  /// Takes a map with keys: id, pubkey, created_at, kind, tags, content, sig.
  /// Returns true if the signature is valid, false otherwise.
  pub fn verify_event(event: beam.term) !bool {
      const EventMap = struct {
          id: []const u8,
          pubkey: []const u8,
          created_at: i64,
          kind: i64,
          tags: []const u8,
          content: []const u8,
          sig: []const u8,
      };

      // Extract fields from event map
      const ev = try beam.get(EventMap, event, .{});

      // Recalculate event ID
      const calculated_id = try calculate_event_id(ev.pubkey, ev.created_at, ev.kind, ev.tags, ev.content);

      // Convert hex strings to bytes
      var bytes_pk: [32]u8 = undefined;
      _ = try std.fmt.hexToBytes(&bytes_pk, ev.pubkey);

      var bytes_sig: [64]u8 = undefined;
      _ = try std.fmt.hexToBytes(&bytes_sig, ev.sig);

      // Convert calculated ID to hex for comparison
      var id_hex: [64]u8 = undefined;
      _ = try std.fmt.bufPrint(&id_hex, "{s}", .{std.fmt.bytesToHex(&calculated_id, .lower)});

      // Verify ID matches
      if (!std.mem.eql(u8, ev.id, &id_hex)) {
          return false;
      }

      // Verify signature - catch any errors and return false
      return verify(bytes_pk, calculated_id, bytes_sig) catch false;
  }
  """

  # Note: Documentation is generated from the Zig code comments above
  # The following functions are NIFs that will be replaced by Zigler at compile time
end
