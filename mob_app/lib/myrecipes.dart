import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // added import
import 'currentrecipe.dart';

class MyRecipesPage extends StatefulWidget {
  const MyRecipesPage({super.key});

  @override
  State<MyRecipesPage> createState() => _MyRecipesPageState();
}

class _MyRecipesPageState extends State<MyRecipesPage> {
  static const _prefsKey = 'recipes_list';
  final List<Map<String, String>> _recipes = [];
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);
      if (jsonString == null || jsonString.isEmpty) {
        setState(() => _recipes.clear());
        return;
      }

      final decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        // corrupted, reset
        debugPrint('recipes_list is not a List, clearing.');
        await prefs.remove(_prefsKey);
        setState(() => _recipes.clear());
        return;
      }

      final List<Map<String, String>> parsed = [];
      for (final item in decoded) {
        try {
          final m = Map<String, String>.from(item as Map);
          if (m.containsKey('id') && m.containsKey('name')) parsed.add(m);
        } catch (_) {
          // skip invalid entry
        }
      }

      setState(() {
        _recipes
          ..clear()
          ..addAll(parsed);
      });
    } catch (e, st) {
      debugPrint('Failed to load recipes: $e\n$st');
      // keep UI usable
      setState(() => _recipes.clear());
    }
  }

  Future<void> _saveRecipes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_recipes));
    } catch (e) {
      debugPrint('Failed to save recipes: $e');
    }
  }

  Future<void> _createRecipeAndOpen() async {
    _nameController.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj novi recept'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Naziv recepta'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Otkaži')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Kreiraj')),
        ],
      ),
    );

    if (ok != true) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final id = 'r_${DateTime.now().millisecondsSinceEpoch}';
    final newRecipe = {'id': id, 'name': name};

    setState(() => _recipes.add(newRecipe));
    await _saveRecipes();

    // Open the recipe page immediately
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CurrentRecipePage(recipeId: id, title: name),
      ),
    );
  }

  Future<void> _removeRecipeAt(int index) async {
    if (index < 0 || index >= _recipes.length) return;
    final removed = Map<String, String>.from(_recipes[index]);
    final recipeId = removed['id'];
    final prefs = await SharedPreferences.getInstance();

    // backup steps for undo
    final stepsKey = 'recipe_${recipeId ?? ''}';
    String? stepsBackup;
    try {
      stepsBackup = prefs.getString(stepsKey);
    } catch (_) {}

    setState(() => _recipes.removeAt(index));
    await _saveRecipes();

    if (recipeId != null) {
      try {
        await prefs.remove(stepsKey);
      } catch (_) {}
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Removed recipe: ${removed['name']}"),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            setState(() => _recipes.insert(index, removed));
            await _saveRecipes();
            if (stepsBackup != null && recipeId != null) {
              try {
                await prefs.setString(stepsKey, stepsBackup);
              } catch (_) {}
            }
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'Nemate nijedan recept\nDodajte novi recept',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if there's a route to return to before allowing any pop.
    final bool canPopNow = Navigator.of(context).canPop();
    final Color scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return WillPopScope(
      onWillPop: () async => Navigator.of(context).canPop(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // background image
          Builder(builder: (ctx) {
            final mq = MediaQuery.of(ctx);
            final int cacheWidth = (mq.size.width * mq.devicePixelRatio).toInt();
            return Image.asset(
              'assets/images/recipes.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: cacheWidth,
              errorBuilder: (c, e, st) => Container(color: Colors.grey.shade200),
            );
          }),

          // reduce blur so the background is more visible but still soft
          Positioned.fill(
            child: BackdropFilter(
              // smaller sigma => sharper, more visible background
              filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
              // very slight tint so content stays readable
              child: Container(color: Colors.white.withOpacity(0.02)),
            ),
          ),

          // gentler gradient overlay to smoothly transition from image -> app background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    // keep the very top mostly transparent so header reads on the image
                    scaffoldBg.withOpacity(0.04),
                    // blend to a soft content background lower down, but allow image to show through
                    scaffoldBg.withOpacity(0.65),
                  ],
                  stops: const [0.0, 0.50],
                ),
              ),
            ),
          ),

          // UI on top of blurred + gradient background; scaffold is transparent so AppBar blends
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text(
                "Moji recepti",
                style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),),
              backgroundColor: Colors.transparent,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              systemOverlayStyle:
                  SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
              iconTheme: const IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
              automaticallyImplyLeading: false,
              leading: canPopNow
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                      },
                    )
                  : null,
            ),
            body: SafeArea(
              top: true,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: _recipes.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _recipes.length,
                        itemBuilder: (ctx, i) {
                          final r = _recipes[i];
                          final idKey = r['id'] ?? 'recipe_$i';
                          return Dismissible(
                            key: ValueKey(idKey),
                            direction: DismissDirection.endToStart, // right -> left
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) => _removeRecipeAt(i),
                            child: Card(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey.shade900.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.75),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: ListTile(
                                title: Text(r['name'] ?? 'Recipe'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CurrentRecipePage(
                                        recipeId: r['id'] ?? 'recipe_$i',
                                        title: r['name'] ?? 'Recipe',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _createRecipeAndOpen,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black, // This will make the + icon black for better contrast
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}