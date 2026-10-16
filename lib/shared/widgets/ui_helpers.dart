import 'package:flutter/material.dart';
import 'package:youwell/core/theme/app_colors.dart';

/// Feedback is displayed inside cards and dialogs.
void toast(BuildContext context, String text) {}
Future<T?> sheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: child,
        ),
      ),
    );
Widget title(String text, {double size = 26}) => Builder(
  builder: (context) => Text(
    text,
    style: TextStyle(
      color: context.colors.text,
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -.7,
    ),
  ),
);
Widget caption(String text) => Builder(
  builder: (context) => Text(
    text,
    style: TextStyle(color: context.colors.muted, fontSize: 13, height: 1.5),
  ),
);
Widget gap([double size = 16]) => SizedBox(height: size);
Widget panel(List<Widget> children, {Color? color}) => Builder(
  builder: (context) => Container(
    padding: const EdgeInsets.all(22),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: color ?? context.colors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: context.colors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  ),
);
Widget tag(String text, {Color? color}) => Builder(
  builder: (context) {
    final accent = color ?? context.colors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  },
);
Widget sectionHead(String heading, String sub) => Padding(
  padding: const EdgeInsets.only(bottom: 22),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [title(heading, size: 32), gap(5), caption(sub)],
  ),
);
Widget meter(double value, String label, String detail) => Builder(
  builder: (context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Flexible(
              child: Text(
                detail,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: context.colors.muted),
              ),
            ),
          ],
        ),
        gap(8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1),
            minHeight: 8,
            backgroundColor: context.colors.raised,
            color: context.colors.accent,
          ),
        ),
      ],
    ),
  ),
);

/// A text dialog that owns its controller, so the field is never disposed
/// while the closing animation still renders it. Pops with the trimmed text.
class TextEntryDialog extends StatefulWidget {
  const TextEntryDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.maxLength,
    this.message,
    this.hint,
    this.maxLines = 3,
    this.minLength = 1,
    this.suggestion,
    this.onSubmit,
  });
  final String title, confirmLabel;
  final String? message, hint;
  final int maxLength, maxLines, minLength;

  /// Optional helper button that fills the field, e.g. today's progress.
  final (String label, String Function() text)? suggestion;

  /// Returns an error to keep the dialog open, or null once the text is used.
  final Future<String?> Function(String text)? onSubmit;

  @override
  State<TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<TextEntryDialog> {
  final _text = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _text.text.trim();
    if (value.length < widget.minLength) {
      setState(
        () => _error = 'Tulis ${widget.minLength}–${widget.maxLength} karakter.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit?.call(value);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = widget.suggestion;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message case final message?) ...[
              Text(message, style: TextStyle(color: context.colors.muted)),
              const SizedBox(height: 12),
            ],
            if (suggestion != null)
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() => _text.text = suggestion.$2()),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(suggestion.$1),
              ),
            TextField(
              controller: _text,
              enabled: !_busy,
              maxLength: widget.maxLength,
              maxLines: widget.maxLines,
              decoration: InputDecoration(
                hintText: widget.hint,
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ValueListenableBuilder(
          valueListenable: _text,
          builder: (context, value, _) => FilledButton(
            onPressed: _busy || value.text.trim().isEmpty ? null : _submit,
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}
