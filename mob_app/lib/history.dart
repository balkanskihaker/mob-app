import 'dart:ui';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'history_list';
      final jsonString = prefs.getString(key);
      
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        setState(() {
          _history = decoded.map((e) => Map<String, String>.from(e)).toList();
        });
      }
    } catch (_) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        // background image
        Builder(builder: (ctx) {
          final mq = MediaQuery.of(ctx);
          final int cacheWidth = (mq.size.width * mq.devicePixelRatio).toInt();
          return Image.asset(
            'assets/images/history.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: cacheWidth,
            errorBuilder: (c, e, st) => Container(color: Colors.grey.shade200),
          );
        }),

        // blur the background
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
            child: Container(color: Colors.transparent),
          ),
        ),

        // gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scaffoldBg.withOpacity(0.06),
                  scaffoldBg.withOpacity(0.85),
                ],
                stops: const [0.0, 0.45],
              ),
            ),
          ),
        ),

        // main content
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text(
              "Istorija",
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          body: SafeArea(
            child: _history.isEmpty
              ? const Center(
                  child: Text(
                    "Niste jos uvek spremali nijedno jelo.",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[_history.length - 1 - index];
                    return Dismissible(
                     key: ValueKey('history_item_${_history.length - 1 - index}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) async {
                        // Remove the item from the list
                        final removedItem = _history.removeAt(_history.length - 1 - index);
                        
                        // Update SharedPreferences
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('history_list', jsonEncode(_history));
                        } catch (_) {
                          // If save fails, revert the removal
                          setState(() {
                            _history.insert(_history.length - index, removedItem);
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Greška pri brisanju stavke')),
                            );
                          }
                          return;
                        }

                        // Show undo option
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Stavka obrisana'),
                              action: SnackBarAction(
                                label: 'Poništi',
                                onPressed: () async {
                                  // Restore the item
                                  setState(() {
                                    _history.insert(_history.length - index, removedItem);
                                  });
                                  // Update SharedPreferences
                                  try {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setString('history_list', jsonEncode(_history));
                                  } catch (_) {
                                    // If save fails, remove the item again
                                    setState(() {
                                      _history.removeAt(_history.length - index);
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Greška pri vraćanju stavke')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          );
                        }
                      },
                      child: Card(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade900.withOpacity(0.15)
                            : Colors.white.withOpacity(0.75),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(
                            item['name'] ?? 'Unknown Recipe',
                          ),
                          subtitle: Text(
                            '${item['date']} ${item['time']}',
                            style: TextStyle(
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ),
      ],
    );
  }
}