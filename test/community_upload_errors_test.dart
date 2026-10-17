import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youwell/features/community/data/supabase_community_store.dart';

/// A failed photo upload names the server's reason, not "check connection".
void main() {
  String message(String text, String? code) =>
      SupabaseCommunityStore.storageMessage(
        StorageException(text, statusCode: code),
      );

  test('A missing bucket points at the phase 5 migration', () {
    expect(message('Bucket not found', '404'), contains('tahap 5'));
    expect(message('Bucket not found', '400'), contains('bucket'));
  });

  test('Size, format and policy problems get their own message', () {
    expect(message('Payload too large', '413'), contains('terlalu besar'));
    expect(message('invalid mime type', '415'), contains('Format'));
    expect(
      message('new row violates row-level security policy', '403'),
      contains('mengizinkan'),
    );
  });

  test('Anything else shows the code and server text', () {
    expect(message('Internal error', '500'), contains('500: Internal error'));
  });
}
