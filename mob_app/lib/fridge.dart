import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FridgePage extends StatefulWidget {
  const FridgePage({super.key});

  @override
  State<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends State<FridgePage> {
  final List<Map<String, String>> _items = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  static const _prefsKey = 'fridge_items';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      setState(() {
        _items
          ..clear()
          ..addAll(decoded.map((e) => Map<String, String>.from(e)));
      });
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_items));
  }

  void _addItem() {
    final name = _nameController.text.trim();
    final qty = _quantityController.text.trim();
    if (name.isEmpty || qty.isEmpty) return;

    setState(() {
      _items.add({'name': name, 'quantity': qty});
    });

    _nameController.clear();
    _quantityController.clear();
    _saveItems();
    Navigator.of(context).pop();
  }

  void _showAddDialog() {
    _nameController.clear();
    _quantityController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Dodaj namirnicu"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Naziv"),
            ),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: "Količina"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Otkaži"),
          ),
          ElevatedButton(
            onPressed: _addItem,
            child: const Text("Dodaj"),
          ),
        ],
      ),
    );
  }

  void _removeItemAt(int index) {
    if (index < 0 || index >= _items.length) return;
    final removed = Map<String, String>.from(_items[index]);
    setState(() => _items.removeAt(index));
    _saveItems();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Uklonjena: ${removed['name']}"),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() => _items.insert(index, removed));
            _saveItems();
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _editItemQuantity(int index) async {
    if (index < 0 || index >= _items.length) return;
    final current = _items[index];
    final qtyController = TextEditingController(text: current['quantity'] ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Izmeni količinu — ${current['name']}'),
        content: TextField(
          controller: qtyController,
          decoration: const InputDecoration(labelText: 'Količina'),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Otkaži')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sačuvaj')),
        ],
      ),
    );

    if (result == true) {
      final newQty = qtyController.text.trim();
      if (newQty.isEmpty) return;
      setState(() => _items[index]['quantity'] = newQty);
      _saveItems();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Frižider",
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
      ),

      body: Stack(
        fit: StackFit.expand,
        children: [
          // fridge background image
          Builder(builder: (ctx) {
            final mq = MediaQuery.of(ctx);
            final int cacheWidth = (mq.size.width * mq.devicePixelRatio).toInt();
            return Image.asset(
              'assets/images/fridge.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: cacheWidth,
              errorBuilder: (c, e, st) => Container(color: Colors.grey.shade200),
            );
          }),

          // reduce blur so background is more visible
          Positioned.fill(
            child: BackdropFilter(
              // smaller sigma => sharper, more visible background
              filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              // keep a very slight tint so content stays readable
              child: Container(color: Colors.white.withOpacity(0.03)),
            ),
          ),

          // gentler gradient so background shows through more clearly
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    // very light at top so header reads but image is still visible
                    scaffoldBg.withOpacity(0.03),
                    // blend to a soft content background lower down
                    scaffoldBg.withOpacity(0.65),
                  ],
                  stops: const [0.0, 0.50],
                ),
              ),
            ),
          ),

          // existing page content on top of blurred+gradient background
          SafeArea(
            top: true,
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: _items.isEmpty
                  ? const Center(
                      child: Text(
                        "Frižider je prazan. Dodajte novu namirnicu.",
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (ctx, index) {
                        final item = _items[index];
                        final key = ValueKey('${item['name']}_$index');
                        return Dismissible(
                          key: key,
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => _removeItemAt(index),
                          child: Card(
                            // translucent card adapts to theme
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade900.withOpacity(0.15)
                                : Colors.white.withOpacity(0.75),
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              title: Text(item['name'] ?? ''),
                              subtitle: item['quantity'] != null && (item['quantity'] ?? '').isNotEmpty
                                  ? Text('Količina: ${item['quantity']}')
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _editItemQuantity(index),
                                    tooltip: 'Izmeni količinu',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Potvrdi brisanje'),
                                          content: Text('Obrisati "${item['name']}"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(false),
                                              child: const Text('Ne'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.of(ctx).pop(true),
                                              child: const Text('Da'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) _removeItemAt(index);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black, // This will make the + icon black for better contrast
        child: const Icon(Icons.add),
      ),
    );
  }
}
