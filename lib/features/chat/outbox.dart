import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/connectivity.dart';
import '../../core/supabase_client.dart';

/// A message typed while offline, waiting to go out.
class PendingMessage {
  const PendingMessage({
    required this.id,
    required this.dealId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.attempts = 0,
  });

  /// Generated on the client, and sent as the row's primary key.
  ///
  /// This is what makes retrying safe. Without it a flush that actually
  /// reached the server but lost the response on the way back would insert
  /// the message a second time; with it, the retry collides on the primary
  /// key and we can treat that collision as "already delivered".
  final String id;
  final String dealId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final int attempts;

  PendingMessage withAttempt() => PendingMessage(
        id: id,
        dealId: dealId,
        senderId: senderId,
        body: body,
        createdAt: createdAt,
        attempts: attempts + 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'deal_id': dealId,
        'sender_id': senderId,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
      };

  factory PendingMessage.fromJson(Map<String, dynamic> json) => PendingMessage(
        id: json['id'] as String,
        dealId: json['deal_id'] as String,
        senderId: json['sender_id'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      );
}

/// Queue of messages typed with no connection, flushed when one returns.
///
/// Chat is the one write worth queuing. It's append-only, order within a
/// thread is the only thing that matters, and nothing about the world can
/// change underneath it in a way that makes a late delivery wrong.
///
/// Deal actions deliberately do NOT go through here. Accepting a request
/// offline would mean deciding, later and without the user present, what to
/// do when someone else's acceptance landed first — two sellers accepting
/// different buyers for one listing is a correctness problem, not a UX one.
/// Those fail fast and ask the user to try again with a connection.
class MessageOutbox {
  MessageOutbox._();

  static const _key = 'message_outbox_v1';
  static const _maxAttempts = 5;
  static const _uuid = Uuid();

  static final _changes = StreamController<void>.broadcast();

  /// Fires whenever the queue's contents change, so an open thread can
  /// re-render its pending bubbles.
  static Stream<void> get onChanged => _changes.stream;

  static bool _flushing = false;

  static String newId() => _uuid.v4();

  static Future<List<PendingMessage>> all() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      // Must be growable: add() mutates what this returns.
      if (raw == null) return <PendingMessage>[];
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => PendingMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('MessageOutbox.all failed: $error');
      return <PendingMessage>[];
    }
  }

  /// Pending messages for one thread, oldest first.
  static Future<List<PendingMessage>> forDeal(String dealId) async {
    final queue = await all();
    return queue.where((m) => m.dealId == dealId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static Future<void> _save(List<PendingMessage> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(queue.map((m) => m.toJson()).toList()));
      _changes.add(null);
    } catch (error) {
      debugPrint('MessageOutbox._save failed: $error');
    }
  }

  static Future<void> add(PendingMessage message) async {
    final queue = await all();
    queue.add(message);
    await _save(queue);
  }

  static Future<void> _remove(String id) async {
    final queue = await all();
    queue.removeWhere((m) => m.id == id);
    await _save(queue);
  }

  static Future<void> _replace(PendingMessage message) async {
    final queue = await all();
    final index = queue.indexWhere((m) => m.id == message.id);
    if (index == -1) return;
    queue[index] = message;
    await _save(queue);
  }

  /// Sends everything queued, oldest first.
  ///
  /// Serial, not parallel: within a thread the order the user typed them in
  /// is the order they should arrive in, and `created_at` is assigned
  /// server-side on insert.
  static Future<void> flush() async {
    if (_flushing) return;
    if (supabase.auth.currentSession == null) return;

    _flushing = true;
    try {
      for (final message in await all()) {
        try {
          await supabase.from('messages').insert({
            'id': message.id,
            'deal_id': message.dealId,
            'sender_id': message.senderId,
            'body': message.body,
          });
          await _remove(message.id);
        } on PostgrestException catch (error) {
          if (error.code == '23505') {
            // Primary key collision: this exact message is already on the
            // server from an earlier attempt whose response we never saw.
            await _remove(message.id);
            continue;
          }
          // Any other Postgres error is the server refusing on the merits —
          // the deal closed, the pharmacy was suspended, RLS said no.
          // Retrying will never change the answer.
          debugPrint('Outbox: dropping message ${message.id}, server refused: ${error.message}');
          await _remove(message.id);
        } catch (error) {
          if (!ConnectivityController.looksOffline(error)) {
            debugPrint('Outbox: dropping message ${message.id}: $error');
            await _remove(message.id);
            continue;
          }
          // Still offline. Stop — the rest of the queue is behind this one
          // and sending them out of order would scramble the thread.
          final attempted = message.withAttempt();
          if (attempted.attempts >= _maxAttempts) {
            debugPrint('Outbox: giving up on message ${message.id}');
            await _remove(message.id);
          } else {
            await _replace(attempted);
          }
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  /// Wired in `main()`. Flushes on every reconnect.
  static void start() {
    connectivityController.onReconnected.listen((_) => unawaited(flush()));
    // Also try once at launch: the app may have been killed with messages
    // still queued from a previous run.
    unawaited(flush());
  }

  /// Sign-out: one pharmacy's unsent messages must not be flushed under the
  /// next account to sign in on this device.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      _changes.add(null);
    } catch (error) {
      debugPrint('MessageOutbox.clear failed: $error');
    }
  }
}
