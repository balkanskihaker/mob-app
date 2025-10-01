import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final List<Map<String, String>> _items = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  static const _prefsKey = 'shopping_list_items'; // different key from fridge

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
          ..addAll(decoded.map((e) {
            final m = Map<String, String>.from(e);
            // backward compatibility: ensure 'checked' key exists
            if (!m.containsKey('checked')) m['checked'] = 'false';
            return m;
          }));
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
    if (name.isEmpty) return;

    setState(() {
      _items.add({'name': name, 'quantity': qty, 'checked': 'false'});
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
        title: const Text("Dodaj stavku"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Naziv"),
            ),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: "Količina (opciono)"),
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
      setState(() => _items[index]['quantity'] = newQty);
      _saveItems();
    }
  }

  void _toggleChecked(int index, bool? checked) {
    if (index < 0 || index >= _items.length) return;
    setState(() {
      _items[index]['checked'] = (checked == true) ? 'true' : 'false';
    });
    _saveItems();
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
      // render body behind the AppBar so the background can show through
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Lista za kupovinu",
          style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        // ensure status bar icons are dark and visible over the light background
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        // ensure AppBar icons (e.g. back button) are dark as well
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
      ),

      body: Stack(
        fit: StackFit.expand,
        children: [
          // background image
          Builder(builder: (ctx) {
            final mq = MediaQuery.of(ctx);
            final int cacheWidth = (mq.size.width * mq.devicePixelRatio).toInt();
            return Image.asset(
              'assets/images/paper.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: cacheWidth,
              errorBuilder: (c, e, st) => Container(color: Colors.grey.shade100),
            );
          }),

          // reduce blur so background is more visible
          Positioned.fill(
            child: BackdropFilter(
              // smaller sigma => sharper, more visible background
              filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
              // keep a very slight tint so content stays readable
              child: Container(color: Colors.white.withOpacity(0.02)),
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
                    // subtle top tint so the AppBar still reads, but image remains visible
                    scaffoldBg.withOpacity(0.06),
                    // softer blend lower down so list content remains readable
                    scaffoldBg.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.40],
                ),
              ),
            ),
          ),

          // content on top of blurred+gradient background; safe area & top padding to avoid AppBar overlap
          SafeArea(
            top: true,
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
              child: _items.isEmpty
                  ? const Center(
                      child: Text(
                        "Lista za kupovinu je prazna. Dodajte novu stavku.",
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _items.length,
                      itemBuilder: (ctx, index) {
                        final item = _items[index];
                        final key = ValueKey('${item['name']}_$index');
                        final checked = (item['checked'] ?? 'false') == 'true';
                        final textStyle = checked
                            ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                            : null;
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
                            // translucent card that adapts to the theme
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade900.withOpacity(0.15)
                                : Colors.white.withOpacity(0.75),
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              leading: Checkbox(
                                value: checked,
                                onChanged: (v) => _toggleChecked(index, v),
                              ),
                              title: Text(item['name'] ?? '', style: textStyle),
                              subtitle: item['quantity'] != null && (item['quantity'] ?? '').isNotEmpty
                                  ? Text('Količina: ${item['quantity']}', style: textStyle)
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
        child: const Icon(Icons.add),
      ),
    );
  }
}