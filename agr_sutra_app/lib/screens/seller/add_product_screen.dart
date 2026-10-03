import 'dart:async';
import 'dart:typed_data';
 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
 
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/wav.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_service.dart';
 
/// The "AI Camera Studio": photo -> clean background -> voice/typed
/// description -> AI listing text -> suggested price -> publish.
class AddProductScreen extends StatefulWidget {
  final VoidCallback onPublished;
  const AddProductScreen({super.key, required this.onPublished});
 
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}
 
class _AddProductScreenState extends State<AddProductScreen> {
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  final List<int> _pcm = [];
  StreamSubscription<Uint8List>? _micSub;
 
  Uint8List? _original;
  Uint8List? _cleaned;
 
  final _raw = TextEditingController();
  final _material = TextEditingController();
  final _name = TextEditingController();
  final _english = TextEditingController();
  final _hindi = TextEditingController();
  final _rawCost = TextEditingController();
  final _labor = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '1');
 
  String _category = kCategories.first;
  String _size = kSizes.first;
  String _voiceLanguage = 'English'; // label chosen for the voice recording
  String _sourceLanguage = 'English'; // language the seller spoke / typed in
 
  bool _recording = false;
  String? _busy; // message shown while something is loading
 
  ProductService get _service =>
      ProductService(context.read<AuthProvider>().api);
 
  @override
  void dispose() {
    _micSub?.cancel();
    _recorder.dispose();
    for (final c in [
      _raw, _material, _name, _english, _hindi, _rawCost, _labor, _price, _stock
    ]) {
      c.dispose();
    }
    super.dispose();
  }
 
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
 
  /// Shows a "working..." banner while [action] runs, and reports errors.
  Future<void> _guard(String message, Future<void> Function() action) async {
    setState(() => _busy = message);
    try {
      await action();
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }
 
  // ------------------------------------------------------------ photo
  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
          source: source, maxWidth: 2000, imageQuality: 90);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _original = bytes;
        _cleaned = null;
      });
      await _clean();
    } catch (e) {
      _toast('Could not open the photo: $e');
    }
  }
 
  Future<void> _clean() async {
    final original = _original;
    if (original == null) return;
    await _guard('Cleaning the photo (the first time can take a minute)...',
        () async {
      try {
        final cleaned = await _service.removeBackground(original);
        if (!mounted) return;
        setState(() => _cleaned = cleaned);
      } on ApiException catch (e) {
        _toast('Could not clean the background (${e.message}). '
            'The original photo will be used.');
      }
    });
  }
 
  // ------------------------------------------------------------ voice
  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopAndTranscribe();
      return;
    }
    if (!await _recorder.hasPermission()) {
      _toast('Microphone permission is needed to record.');
      return;
    }
    _pcm.clear();
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));
    _micSub = stream.listen((chunk) => _pcm.addAll(chunk));
    setState(() => _recording = true);
  }
 
  Future<void> _stopAndTranscribe() async {
    await _recorder.stop();
    await _micSub?.cancel();
    _micSub = null;
    if (!mounted) return;
    setState(() => _recording = false);
 
    // 16000 samples/second x 2 bytes = 32000 bytes per second
    if (_pcm.length < 32000) {
      _toast('That recording was too short. Please try again.');
      return;
    }
    final wav = pcmToWav(Uint8List.fromList(_pcm));
    await _guard('Understanding your voice...', () async {
      final result = await _service.transcribe(wav, _voiceLanguage);
      if (!mounted) return;
      setState(() {
        _raw.text = _raw.text.trim().isEmpty
            ? result.transcript
            : '${_raw.text.trim()} ${result.transcript}';
        if (result.language.isNotEmpty) _sourceLanguage = result.language;
      });
    });
  }
 
  // ------------------------------------------------------------ AI text
  Future<void> _generate() async {
    final raw = _raw.text.trim();
    if (raw.isEmpty) {
      _toast('Describe your product first: speak or type.');
      return;
    }
    await _guard('Writing your listing...', () async {
      final copy = await _service.catalogCopy(
        raw: raw,
        category: _category,
        material: _material.text.trim(),
        sourceLanguage: _sourceLanguage,
      );
      if (!mounted) return;
      setState(() {
        _name.text = copy.name;
        _english.text = copy.english;
        _hindi.text = copy.hindi;
        if (_material.text.trim().isEmpty) _material.text = copy.material;
      });
      if (!copy.usedAi) {
        _toast('Gemini is not available, so a basic template was used. '
            'You can edit the text.');
      }
    });
  }
 
  // ------------------------------------------------------------ price
  Future<void> _suggest() async {
    final raw = double.tryParse(_rawCost.text.trim());
    final labor = double.tryParse(_labor.text.trim());
    if (raw == null || labor == null) {
      _toast('Enter the material cost and the labour cost as numbers.');
      return;
    }
    await _guard('Calculating a fair price...', () async {
      final price = await _service.suggestPrice(
        category: _category,
        size: _size,
        rawCost: raw,
        laborCost: labor,
      );
      if (!mounted) return;
      if (price <= 0) {
        _toast('Costs must be above zero.');
        return;
      }
      setState(() => _price.text = price.toString());
    });
  }
 
  // ------------------------------------------------------------ publish
  Future<void> _publish() async {
    final image = _cleaned ?? _original;
    final price = int.tryParse(_price.text.trim());
    final stock = int.tryParse(_stock.text.trim());
    if (image == null) {
      _toast('Add a product photo first.');
      return;
    }
    if (_name.text.trim().isEmpty) {
      _toast('Add a product name (tap "Write my listing").');
      return;
    }
    if (price == null || price <= 0) {
      _toast('Enter a price above 0.');
      return;
    }
    if (stock == null || stock < 0) {
      _toast('Enter how many you have in stock.');
      return;
    }
    await _guard('Publishing...', () async {
      await _service.createProduct(
        image: image,
        name: _name.text.trim(),
        category: _category,
        material: _material.text.trim(),
        price: price,
        stock: stock,
        englishDesc: _english.text.trim(),
        hindiDesc: _hindi.text.trim(),
        language: _sourceLanguage,
      );
      if (!mounted) return;
      _toast('Your product is published!');
      _reset();
      widget.onPublished();
    });
  }
 
  void _reset() {
    setState(() {
      _original = null;
      _cleaned = null;
      for (final c in [
        _raw, _material, _name, _english, _hindi, _rawCost, _labor, _price
      ]) {
        c.clear();
      }
      _stock.text = '1';
      _category = kCategories.first;
      _size = kSizes.first;
      _sourceLanguage = 'English';
    });
  }
 
  // ------------------------------------------------------------ UI
  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
 
  InputDecoration _decor(String label, {String? hint}) => InputDecoration(
      border: const OutlineInputBorder(), labelText: label, hintText: hint);
 
  Widget _dropdown(String label, String value, List<String> items,
      void Function(String) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: _decor(label),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final preview = _cleaned ?? _original;
    return Column(
      children: [
        if (_busy != null)
          Container(
            color: Theme.of(context).colorScheme.secondaryContainer,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 6),
                Text(_busy!, textAlign: TextAlign.center),
              ],
            ),
          ),
        Expanded(
          child: AbsorbPointer(
            absorbing: _busy != null,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('1. Product photo', [
                  if (preview != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(preview, height: 220, fit: BoxFit.contain),
                    ),
                  if (preview != null) const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                  if (_original != null && _cleaned != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Background removed and lighting improved.',
                          style: TextStyle(fontSize: 12)),
                    ),
                ]),
                _section('2. Describe your product', [
                  _dropdown('Language you will speak', _voiceLanguage, kLanguages,
                      (v) => setState(() {
                            _voiceLanguage = v;
                            _sourceLanguage = languageEnglishName(v);
                          })),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _toggleRecording,
                    icon: Icon(_recording ? Icons.stop : Icons.mic),
                    label: Text(
                        _recording ? 'Stop recording' : 'Speak your description'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _raw,
                    maxLines: 4,
                    decoration: _decor('Description (spoken text appears here, or type)'),
                  ),
                  const SizedBox(height: 12),
                  _dropdown('Category', _category, kCategories,
                      (v) => setState(() => _category = v)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _material,
                      decoration: _decor('Material (optional)', hint: 'e.g. Clay, Cotton')),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Write my listing'),
                  ),
                ]),
                _section('3. Your listing (you can edit)', [
                  TextField(controller: _name, decoration: _decor('Product name')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _english,
                      maxLines: 5,
                      decoration: _decor('English description')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _hindi,
                      maxLines: 5,
                      decoration: _decor('Hindi description')),
                ]),
                _section('4. Price and stock', [
                  _dropdown('Size', _size, kSizes, (v) => setState(() => _size = v)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                            controller: _rawCost,
                            keyboardType: TextInputType.number,
                            decoration: _decor('Material cost (₹)')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                            controller: _labor,
                            keyboardType: TextInputType.number,
                            decoration: _decor('Labour cost (₹)')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _suggest,
                    icon: const Icon(Icons.calculate),
                    label: const Text('Suggest a price'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                            controller: _price,
                            keyboardType: TextInputType.number,
                            decoration: _decor('Selling price (₹)')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                            controller: _stock,
                            keyboardType: TextInputType.number,
                            decoration: _decor('Stock')),
                      ),
                    ],
                  ),
                ]),
                FilledButton(
                  onPressed: _publish,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Publish product'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}