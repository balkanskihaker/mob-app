import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'app_state.dart';

class CurrentRecipeView extends StatefulWidget {
  final String recipeId;
  final String title;

  const CurrentRecipeView({
    super.key,
    required this.recipeId,
    required this.title,
  });

  @override
  State<CurrentRecipeView> createState() => _CurrentRecipeViewState();
}

class _CurrentRecipeViewState extends State<CurrentRecipeView> {
  final List<Map<String, String>> _steps = [];
  static const _prefix = 'recipe_'; // stored under recipe_<id>

  @override
  void initState() {
    super.initState();
    // Start cooking mode
    appState.startCooking(widget.recipeId, widget.title);
    _loadSteps();
  }

  @override
  void dispose() {
    // Clear active marker when the view is destroyed
    if (appState.activeRecipe.value != null &&
        appState.activeRecipe.value!['id'] == widget.recipeId) {
      appState.activeRecipe.value = null;
    }
    super.dispose();
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
        title: const Text('Add step'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Step text'),
          maxLines: null,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
        ],
      ),
    );

    if (ok == true) {
      final text = controller.text.trim();
      if (text.isEmpty) return;
      setState(() => _steps.add({'type': 'text', 'value': text, 'checked': 'false'}));
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
      setState(() => _steps.add({'type': 'image', 'value': b64, 'checked': 'false'}));
      await _saveSteps();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add image')));
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
              title: const Text('Add text step'),
              onTap: () {
                Navigator.of(ctx).pop();
                _addTextStep();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Add image step'),
              onTap: () {
                Navigator.of(ctx).pop();
                _addImageStep();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
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

  Future<void> _addToHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'history_list';
      final jsonString = prefs.getString(key);
      final List<Map<String, String>> entries = [];
      
      if (jsonString != null && jsonString.isNotEmpty) {
        try {
          final decoded = jsonDecode(jsonString);
          if (decoded is List) {
            for (final e in decoded) {
              entries.add(Map<String, String>.from(e));
            }
          }
        } catch (_) {}
      }

      // Get current date and time
      final now = DateTime.now();
      final date = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      entries.add({
        'name': widget.title,
        'date': date,
        'time': time,
      });

      await prefs.setString(key, jsonEncode(entries));
    } catch (_) {
      // ignore storage errors
    }
  }

  void _toggleStepChecked(int index, bool? checked) {
    if (index < 0 || index >= _steps.length) return;
    setState(() {
      _steps[index]['checked'] = (checked == true).toString();
    });
    _saveSteps();
  }

  Widget _buildStepTile(Map<String, String> step, int index) {
    if (step['type'] == 'image') {
      final String? b64 = step['value'];
      if (b64 == null || b64.isEmpty) {
        return const ListTile(title: Text('Empty image'));
      }

      try {
        final Uint8List data = base64Decode(b64);
        final int targetWidth = (MediaQuery.of(context).size.width * 0.9).toInt();
        final imageProvider = ResizeImage(MemoryImage(data), width: targetWidth);
        final checked = (step['checked'] ?? 'false') == 'true';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) => const ListTile(
                    title: Text('Image unavailable'),
                    leading: Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // keep checkbox compact and vertically centered
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: checked,
                    onChanged: (v) => _toggleStepChecked(index, v),
                  ),
                ],
              ),
            ],
          ),
        );
      } catch (_) {
        return const ListTile(
          title: Text('Invalid image data'),
          leading: Icon(Icons.broken_image),
        );
      }
    } else {
      final checked = (step['checked'] ?? 'false') == 'true';
      return ListTile(
        title: Text(
          step['value'] ?? '',
          style: checked ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey) : null,
        ),
        // move checkbox to the trailing side
        trailing: Checkbox(
          value: checked,
          onChanged: (v) => _toggleStepChecked(index, v),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Intercept system back: just pop and return
    return WillPopScope(
      onWillPop: () async {
        if (!mounted) return true;
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (!mounted) return;
              Navigator.of(context).pop();
            },
          ),
          title: Text(widget.title),
          actions: const [],
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
                  return Card(
                    child: InkWell(
                      onLongPress: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Potvrdi brisanje koraka'),
                            content: const Text('Obrisati ovaj korak?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Ne')),
                              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Da')),
                            ],
                          ),
                        );
                        if (confirm == true) _removeStepAt(i);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _buildStepTile(step, i),
                      ),
                    ),
                  );
                },
              ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cancel and Finish buttons
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        // Reset all checkboxes
                        setState(() {
                          for (var step in _steps) {
                            step['checked'] = 'false';
                          }
                        });
                        await _saveSteps();
                        // Stop cooking mode and return to main
                        appState.stopCooking();
                        if (context.mounted) {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                      },
                      child: const Text('Otkaži'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _addToHistory();
                        // Stop cooking mode and return to main
                        appState.stopCooking();
                        if (context.mounted) {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                      },
                      child: const Text('Završi'),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Navigation Bar
            BottomNavigationBar(
              currentIndex: appState.currentTab.value,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.teal,
              unselectedItemColor: Colors.grey,
              onTap: (index) {
                appState.switchTab(index);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: "Danas"),
                BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Istorija"),
                BottomNavigationBarItem(icon: Icon(Icons.book), label: "Recepti"),
                BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "Frizider"),
                BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Kupovina"),
              ],
            ),
          ],
        ),
      ),
    );
  }
}