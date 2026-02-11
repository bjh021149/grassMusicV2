import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchShortcut extends StatefulWidget {
  final Widget child;
  final Function(String) onSearch;

  const SearchShortcut({
    super.key,
    required this.child,
    required this.onSearch,
  });

  @override
  createState() => _SearchShortcutState();
}

class _SearchShortcutState extends State<SearchShortcut> {
  final FocusNode _focusNode = FocusNode();
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(_handleKeyEvent);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final isControlPressed = event.isControlPressed;
      final isMetaPressed = event.isMetaPressed;
      final isShiftPressed = event.isShiftPressed;

      // Check for C+S (Control+Shift+S or Command+Shift+S on Mac)
      if ((isControlPressed || isMetaPressed) &&
          isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyS) {
        setState(() {
          _showSearch = true;
        });
        // Focus the search field when it appears
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(_focusNode);
        });
      }

      // Close on Escape
      if (event.logicalKey == LogicalKeyboardKey.escape && _showSearch) {
        setState(() {
          _showSearch = false;
          _searchController.clear();
        });
      }
    }
  }

  void _performSearch() {
    if (_searchController.text.isNotEmpty) {
      widget.onSearch(_searchController.text);
    }
    setState(() {
      _showSearch = false;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showSearch) ...[
          // Semi-transparent background
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showSearch = false;
                  _searchController.clear();
                });
              },
              child: Container(color: Colors.black54),
            ),
          ),
          // Search box
          Center(
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _showSearch = false;
                              _searchController.clear();
                            });
                          },
                        ),
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _performSearch,
                      child: const Text('Search'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
