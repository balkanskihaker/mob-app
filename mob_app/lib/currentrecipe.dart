import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class CurrentRecipePage extends StatefulWidget {
  final String recipeId;
  final String title;

  const CurrentRecipePage({
    super.key,
    required this.recipeId,
    required this.title,
  });

  @override
  State<CurrentRecipePage> createState() => _CurrentRecipePageState();
}

class _CurrentRecipePageState extends State<CurrentRecipePage> {
  final List<Map<String, String>> _steps = [];
  static const _prefix = 'recipe_'; // stored under recipe_<id>

  @override
  void initState() {
    super.initState();
    _loadSteps();
  }

  Future<void> _loadSteps() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_prefix${widget.recipeId}');
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        setState(() {
          _steps
            ..clear()
            ..addAll(decoded.map((e) => Map<String, String>.from(e)));
        });
      } catch (_) {
        // corrupted steps -> start empty
        setState(() => _steps.clear());
      }
    }
  }

  Future<void> _saveSteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix${widget.recipeId}', jsonEncode(_steps));
  }

  Future<void> _addTextStep() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj tekstualni korak'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tekst'),
          maxLines: null,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Otkaži')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Dodaj')),
        ],
      ),
    );

    if (ok == true) {
      final text = controller.text.trim();
      if (text.isEmpty) return;
      // add simple step without checkbox flag
      setState(() => _steps.add({'type': 'text', 'value': text}));
      await _saveSteps();
    }
  }

  Future<void> _addImageStep() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      // add image step without checkbox flag
      setState(() => _steps.add({'type': 'image', 'value': b64}));
      await _saveSteps();
    } catch (e) {
      // ignore; show user-friendly message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Greška pri učitavanju slike')));
      }
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Dodaj tekstualni korak'),
              onTap: () {
                Navigator.of(ctx).pop();
                _addTextStep();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Dodaj sliku'),
              onTap: () {
                Navigator.of(ctx).pop();
                _addImageStep();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Otkaži'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _removeStepAt(int index) {
    if (index < 0 || index >= _steps.length) return;
    final removed = Map<String, String>.from(_steps[index]);
    setState(() => _steps.removeAt(index));
    _saveSteps();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Step removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() => _steps.insert(index, removed));
            _saveSteps();
          },
        ),
      ),
    );
  }

  // removed _toggleStepChecked - no checkbox handling anymore

  Widget _buildStepTile(Map<String, String> step, int index) {
    if (step['type'] == 'image') {
      final String? b64 = step['value'];
      if (b64 == null || b64.isEmpty) {
        return const ListTile(title: Text('Empty image'));
      }

      // Defensive decode + downscale the MemoryImage to avoid Impeller/GLES mipmap issues
      try {
        final Uint8List data = base64Decode(b64);
        final int targetWidth = (MediaQuery.of(context).size.width * 0.9).toInt();
        final imageProvider = ResizeImage(MemoryImage(data), width: targetWidth);

        // show the image full width (no checkbox)
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Image(
            image: imageProvider,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) => const ListTile(
              title: Text('Image unavailable'),
              leading: Icon(Icons.broken_image),
            ),
          ),
        );
      } catch (_) {
        return const ListTile(
          title: Text('Invalid image data'),
          leading: Icon(Icons.broken_image),
        );
      }
    } else {
      // simple text step (no trailing checkbox)
      return ListTile(
        title: Text(step['value'] ?? ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Intercept system back: just pop and return (avoid importing MyRecipesPage to prevent circular import)
    return WillPopScope(
      onWillPop: () async {
        if (!mounted) return true;
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          // replace default back behaviour with explicit navigation to MyRecipesPage
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (!mounted) return;
              Navigator.of(context).pop();
            },
          ),
          title: Text(widget.title),
          actions: [
            if (_steps.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_forever),
                tooltip: 'Clear all steps',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Obriši sve korake'),
                      content: const Text('Da li ste sigurni da želite da obrišete sve korake?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Ne')),
                        ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Da')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    setState(() => _steps.clear());
                    await _saveSteps();
                  }
                },
              ),
          ],
        ),
        body: _steps.isEmpty
            ? Center(
                child: Text(
                  'Nema nijednog koraka za ovaj recept',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _steps.length,
                itemBuilder: (ctx, i) {
                  final step = _steps[i];
                  return Dismissible(
                    key: ValueKey('step_${i}_${step['type']}_${step['value']?.hashCode}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _removeStepAt(i),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _buildStepTile(step, i),
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddOptions,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black, // This will make the + icon black for better contrast
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}