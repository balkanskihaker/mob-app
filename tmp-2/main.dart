import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- add this
import 'package:shared_preferences/shared_preferences.dart';

import 'fridge.dart';
import 'history.dart';
import 'myrecipes.dart';
import 'myrecipesview.dart'; // added import
import 'shoppinglist.dart';
import 'currentrecipe.dart';
import 'currentrecipeview.dart'; // <-- new
import 'app_state.dart'; // make sure this import exists

// global key to control the MainScaffold from pages (so we can switch tabs and push routes
// from the scaffold's context, preserving the bottom bar and correct navigation stack)
final GlobalKey<_MainScaffoldState> mainScaffoldKey = GlobalKey<_MainScaffoldState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Cooking App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      // use the keyed scaffold so other pages  can access its context/state
      home: MainScaffold(key: mainScaffoldKey),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    TodaysMenuPage(),
    HistoryPage(),
    MyRecipesPage(),
    FridgePage(),
    ShoppingListPage(),
  ];

  // allow external callers to switch tab
  void switchTo(int idx) {
    if (!mounted) return;
    setState(() => _currentIndex = idx);
  }

  @override
  void initState() {
    super.initState();
    // Listen for tab change requests
    appState.currentTab.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() {
      _currentIndex = appState.currentTab.value;
    });
  }

  @override
  void dispose() {
    appState.currentTab.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleNavigation(int index, BuildContext context) {
    if (index == 0 && appState.isCooking.value && appState.activeRecipe.value != null) {
      // If "Danas" is tapped and we're cooking, show the active recipe
      final info = appState.activeRecipe.value!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CurrentRecipeView(
            recipeId: info['id'] ?? '',
            title: info['title'] ?? '',
          ),
        ),
      );
    } else {
      // Otherwise just switch tabs
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) => _handleNavigation(index, context),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: "Danas"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Istorija"),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: "Recepti"),
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "Frizider"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Kupovina"),
        ],
      ),
    );
  }
}

class TodaysMenuPage extends StatelessWidget {
  const TodaysMenuPage({super.key});

  Future<void> _createRecipeFromMenu(BuildContext context) async {
    // create controller for the dialog; DO NOT dispose it immediately,
    // disposing while the dialog is animating can cause "used after dispose" crashes
    final TextEditingController nameController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create recipe'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Recipe name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create')),
        ],
      ),
    );

    if (ok != true) {
      // don't dispose during widget tree rebuild/animation — let GC handle it
      return;
    }

    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final id = 'r_${DateTime.now().millisecondsSinceEpoch}';
    final newRecipe = {'id': id, 'name': name};

    // Persist using the same robust logic as MyRecipesPage
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'recipes_list';
      final jsonString = prefs.getString(key);

      List<dynamic> list = [];
      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = jsonDecode(jsonString);
        if (decoded is List) {
          list = decoded;
        } else {
          // corrupted value -> reset to empty list
          await prefs.remove(key);
          list = [];
        }
      }

      list.add(newRecipe);
      await prefs.setString(key, jsonEncode(list));
    } catch (e) {
      // keep UI usable even if saving fails
      debugPrint('Failed to save new recipe: $e');
    }

    if (!context.mounted) return;

    // Switch bottom tab to My Recipes, then push the CurrentRecipePage from the scaffold's context.
    mainScaffoldKey.currentState?.switchTo(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // prefer scaffold context so the pushed page sits above the scaffold (keeps bottom bar)
      final pushCtx = mainScaffoldKey.currentContext ?? context;
      if (!pushCtx.mounted) return;
      Navigator.of(pushCtx).push(
        MaterialPageRoute(builder: (_) => CurrentRecipePage(recipeId: id, title: name)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Danasnji meni",
          style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: 
            SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (downscaled)
          Builder(builder: (ctx) {
            final mq = MediaQuery.of(ctx);
            final int cacheWidth = (mq.size.width * mq.devicePixelRatio / 1.5).toInt();
            return Image(
              image: ResizeImage(const AssetImage("assets/images/kitchen_background.jpg"),
                  width: cacheWidth),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (c, e, st) => Container(color: Colors.grey.shade900),
            );
          }),

          // blur the background
          Positioned.fill(
            child: BackdropFilter(
              // reduce sigma to keep more texture visible
              filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
              child: Container(color: Colors.transparent),
            ),
          ),

          // subtler gradient overlay for a smoother, more transparent transition
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    // very light at the top so the image is clearly visible behind the title
                    scaffoldBg.withOpacity(0.06),
                    // gentle blend toward the app background lower down
                    scaffoldBg.withOpacity(0.40),
                  ],
                  stops: const [0.0, 0.40],
                ),
              ),
            ),
          ),

          // content (inside SafeArea so it doesn't clash with the transparent app bar)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Izaberite neki od postojećih recepata",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // open the dedicated MyRecipesView page instead of switching to the tab
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MyRecipesView()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text(
                      "Izaberi recept",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    "Ili kreirajte novi recept",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _createRecipeFromMenu(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text(
                      "Novi recept",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExistingRecipePage extends StatelessWidget {
  const ExistingRecipePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Existing Recipe")),
      body: const Center(child: Text("Ovde će biti detalji o receptu")),
    );
  }
}

class NewRecipePage extends StatelessWidget {
  const NewRecipePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Recipe")),
      body: const Center(child: Text("Ovde ćete moći da dodate novi recept")),
    );
  }
}
