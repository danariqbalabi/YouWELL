import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/activity/data/meal_photo_store.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class MealSnapPage extends StatefulWidget {
  const MealSnapPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<MealSnapPage> createState() => _MealSnapPageState();
}

class _MealSnapPageState extends State<MealSnapPage> {
  final _picker = ImagePicker();
  Uint8List? _photo;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _recoverInterruptedPick();
  }

  Future<void> _recoverInterruptedPick() async {
    try {
      final response = await _picker.retrieveLostData();
      final image = response.files?.firstOrNull;
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      // The camera action remains available.
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 72,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() {
          _photo = bytes;
          _error = null;
        });
      }
    } on PlatformException catch (error) {
      // Only a denied or missing camera swaps the photo quest for a check-off.
      if (!_cameraUnavailableCodes.contains(error.code)) {
        _retryLater();
        return;
      }
      widget.controller.markCameraUnavailable();
      if (mounted) {
        setState(
          () => _error =
              'Kamera belum bisa dibuka. Misi foto hari ini diganti jadi '
              '"Tambahkan buah atau sayur" yang cukup dicentang.',
        );
      }
    } catch (_) {
      _retryLater();
    }
  }

  void _retryLater() {
    if (mounted) {
      setState(() => _error = 'Foto belum bisa diambil. Coba sekali lagi.');
    }
  }

  Future<void> _save() async {
    final photo = _photo;
    if (photo == null || _saving) return;
    setState(() => _saving = true);
    try {
      if (kIsWeb) {
        // On the web the photo is proof of an in-the-moment check-in only.
        // Keep no image bytes or path after submission.
        widget.controller.recordMeal(photoCaptured: true);
      } else {
        final path = await MealPhotoStore.save(photo);
        if (path == null) {
          throw const FormatException('Penyimpanan foto tidak tersedia.');
        }
        widget.controller.recordMeal(photoPath: path);
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                kIsWeb
                    ? 'Mantap! Meal Snap selesai. Fotonya tidak disimpan.'
                    : 'Mantap! Meal Snap tersimpan di perangkatmu.',
              ),
            ),
          );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Foto belum bisa disimpan di perangkat ini. Coba lagi.';
        });
      }
    }
  }


  Future<void> _noteOnly() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const TextEntryDialog(
        title: 'Catat tanpa foto',
        message: 'Masuk ke jurnal pribadimu. Misi Meal Snap tetap butuh foto.',
        hint: 'Apa yang kamu makan?',
        maxLength: 200,
        confirmLabel: 'Simpan',
      ),
    );
    if (note == null || !mounted) return;
    widget.controller.recordMeal(note: note);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Meal Snap')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'Catat makanmu',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Jurnal visual pribadi. Tanpa hitung kalori atau penilaian makanan.',
          style: TextStyle(color: context.colors.muted),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: _saving ? null : _noteOnly,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Catat tanpa foto'),
        ),
        Container(
          height: 280,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.colors.border),
          ),
          child: _photo == null
              ? Center(
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 72,
                    color: context.colors.muted,
                  ),
                )
              : Image.memory(_photo!, fit: BoxFit.cover),
        ),
        const SizedBox(height: 18),
        // Camera only: a quest photo must be taken now, not picked (§7).
        OutlinedButton.icon(
          onPressed: () => _pick(ImageSource.camera),
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(_photo == null ? 'Ambil foto' : 'Foto ulang'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: TextStyle(color: context.colors.amber)),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _photo == null || _saving ? null : _save,
          icon: const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Menyimpan...' : 'Simpan momen'),
        ),
      ],
    ),
  );
}

/// image_picker codes for a camera the user denied or the device lacks.
const _cameraUnavailableCodes = {
  'camera_access_denied',
  'camera_access_restricted',
  'no_available_camera',
};
