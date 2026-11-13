// lib/screens/bible_lists_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_data_models.dart';
import '../services/user_data_service.dart';
import '../services/bible_service.dart';
import '../services/playlist_player_service.dart';
import 'bible_list_detail_screen.dart';
import '../widgets/scripture_playlist_player_sheet.dart';
import '../theme/imago_theme.dart';

class BibleListsScreen extends StatefulWidget {
  const BibleListsScreen({super.key});

  @override
  State<BibleListsScreen> createState() => _BibleListsScreenState();
}

enum _ListFilter { all, presets, custom }

class _BibleListsScreenState extends State<BibleListsScreen> {
  List<BibleList> _lists = [];
  bool _isLoading = true;
  _ListFilter _filter = _ListFilter.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    setState(() => _isLoading = true);
    final lists = await UserDataService.instance.getBibleLists();
    if (mounted) {
      setState(() {
        _lists = lists;
        _isLoading = false;
      });
    }
  }

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return ImagoColors.violet;
    }
  }

  List<BibleList> get _filteredLists {
    return _lists.where((l) {
      if (_filter == _ListFilter.presets && !l.isPreset) return false;
      if (_filter == _ListFilter.custom && l.isPreset) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return l.title.toLowerCase().contains(q) || l.description.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  Future<void> _showCreateListModal() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final scripturesController = TextEditingController();
    String selectedColor = '#3D5AFE';

    final colorOptions = [
      '#3D5AFE', '#00E676', '#FFC857', '#FF4081', '#9C27B0', '#00B4D8'
    ];

    final isDark = ImagoColors.isDark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? ImagoColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              decoration: BoxDecoration(
                color: isDark ? ImagoColors.surface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? ImagoColors.secondaryText.withOpacity(0.25) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Create Bible List',
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A), fontFamily: 'Poppins'),
                      decoration: InputDecoration(
                        labelText: 'List Title',
                        labelStyle: TextStyle(color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B)),
                        hintText: 'e.g. Morning Warfare Prayers, Peace in Anxiety',
                        hintStyle: TextStyle(color: isDark ? ImagoColors.secondaryText.withOpacity(0.4) : const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? ImagoColors.cardBackground : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: descController,
                      style: TextStyle(color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A), fontFamily: 'Poppins'),
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        labelStyle: TextStyle(color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B)),
                        hintText: 'e.g. Verses I listen to every morning',
                        hintStyle: TextStyle(color: isDark ? ImagoColors.secondaryText.withOpacity(0.4) : const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? ImagoColors.cardBackground : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Scriptures
                    TextField(
                      controller: scripturesController,
                      maxLines: 3,
                      style: TextStyle(color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A), fontFamily: 'Poppins'),
                      decoration: InputDecoration(
                        labelText: 'Scripture References',
                        labelStyle: TextStyle(color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B)),
                        hintText: 'e.g. Psalm 23:1-6\nPhilippians 4:6-7\nJohn 3:16',
                        hintStyle: TextStyle(color: isDark ? ImagoColors.secondaryText.withOpacity(0.4) : const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? ImagoColors.cardBackground : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                      // Color picker chips
                      Text(
                        'Accent Color',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: ImagoColors.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: colorOptions.map((hex) {
                          final color = _parseColor(hex);
                          final isSelected = selectedColor == hex;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedColor = hex),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: ImagoColors.primaryText, width: 2.5)
                                    : null,
                                boxShadow: isSelected
                                    ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 10)]
                                    : [],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) return;

                            final rawScriptures = scripturesController.text.trim();
                            final references = BibleService.instance.extractScriptureReferences(rawScriptures);

                            final newList = BibleList(
                              title: title,
                              description: descController.text.trim(),
                              colorHex: selectedColor,
                              isPreset: false,
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            );

                            await UserDataService.instance.saveBibleList(newList, initialReferences: references);
                            Navigator.pop(ctx);
                            _loadLists();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ImagoColors.gold,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Create & Build Lineup',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

  Future<void> _playListDirectly(BibleList list) async {
    if (list.items.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (ctx) => BibleListDetailScreen(listId: list.id!)),
      ).then((_) => _loadLists());
      return;
    }

    final List<BiblePlaylistItem> playlistItems = [];
    for (final item in list.items) {
      final verses = await BibleService.instance.getVerseByReference(item.reference);
      if (verses.isNotEmpty) {
        final startRef = verses.first.reference;
        final displayTitle = item.customTitle.isNotEmpty
            ? item.customTitle
            : (verses.length > 1
                ? '${verses.first.bookName} ${verses.first.chapter}:${verses.first.verse}-${verses.last.verse}'
                : startRef);

        playlistItems.add(BiblePlaylistItem(
          reference: item.reference,
          displayTitle: displayTitle,
          verses: verses,
        ));
      }
    }

    if (playlistItems.isNotEmpty) {
      await PlaylistPlayerService.instance.loadPlaylist(
        list.title,
        playlistItems,
        autoPlay: true,
      );
      if (mounted) {
        ScripturePlaylistPlayerSheet.show(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        final isDark = ImagoColors.isDark;
        final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;
        final bg = isDark
            ? const Color(0xFF0A0E1A)
            : (isParchment ? const Color(0xFFF7F2E7) : const Color(0xFFF8FAFC));
        final cardBg = isDark
            ? const Color(0xFF131D33)
            : (isParchment ? const Color(0xFFFFFDF8) : Colors.white);
        final borderColor = isDark
            ? const Color(0xFF1E293B)
            : (isParchment ? const Color(0xFFE5DAC6) : const Color(0xFFE2E8F0));
        final textPrimary = isDark
            ? Colors.white
            : (isParchment ? const Color(0xFF2C241D) : const Color(0xFF0F172A));
        final textSecondary = isDark
            ? const Color(0xFF94A3B8)
            : (isParchment ? const Color(0xFF6B5E54) : const Color(0xFF64748B));

        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              CosmicBackground(children: const []),
              Positioned(
                top: -60,
                left: -60,
                child: CosmicOrb(size: 300, color: ImagoColors.violet, opacity: isDark ? 0.08 : 0.04),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(isDark, cardBg, borderColor, textPrimary),
                    _buildFilterChips(isDark, cardBg, borderColor, textSecondary),
                    Expanded(child: _buildBody(isDark, cardBg, borderColor, textPrimary, textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showCreateListModal,
            backgroundColor: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.playlist_add_rounded, size: 22),
            label: const Text(
              'New Bible List',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark, Color cardBg, Color borderColor, Color textPrimary) {
    final canPop = Navigator.canPop(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (canPop) ...[
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? ImagoColors.cardBackground : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 16),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Text(
                'Bible Lists',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: TextStyle(color: textPrimary, fontFamily: 'Poppins'),
            decoration: InputDecoration(
              hintText: 'Search scripture lists...',
              hintStyle: TextStyle(color: isDark ? ImagoColors.secondaryText.withOpacity(0.5) : const Color(0xFF94A3B8), fontSize: 13.5),
              prefixIcon: Icon(Icons.search_rounded, color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? ImagoColors.cardBackground : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark, Color cardBg, Color borderColor, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildChip('All Lists', _ListFilter.all, isDark, cardBg, borderColor, textSecondary),
          const SizedBox(width: 8),
          _buildChip('Inspirational', _ListFilter.presets, isDark, cardBg, borderColor, textSecondary),
          const SizedBox(width: 8),
          _buildChip('My Lists', _ListFilter.custom, isDark, cardBg, borderColor, textSecondary),
        ],
      ),
    );
  }

  Widget _buildChip(String label, _ListFilter filter, bool isDark, Color cardBg, Color borderColor, Color textSecondary) {
    final isSelected = _filter == filter;
    final activeBg = isDark ? ImagoColors.gold : const Color(0xFF4F46E5);
    final activeTextColor = isDark ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeBg : borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: isSelected ? activeTextColor : textSecondary,
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5)),
      );
    }

    final lists = _filteredLists;

    if (lists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_remove_rounded, size: 64, color: textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No Bible lists found',
              style: TextStyle(
                fontFamily: 'Cinzel',
                color: textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: lists.length,
      itemBuilder: (context, index) {
        final list = lists[index];
        final accentColor = _parseColor(list.colorHex);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => BibleListDetailScreen(listId: list.id!)),
            ).then((_) => _loadLists());
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? accentColor.withOpacity(0.35) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? accentColor.withOpacity(0.08) : const Color(0xFF64748B).withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(isDark ? 0.15 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.queue_music_rounded, color: accentColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              list.title,
                              style: TextStyle(
                                fontFamily: 'Cinzel',
                                color: textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (list.isPreset)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? ImagoColors.gold.withOpacity(0.2) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Curated',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: isDark ? ImagoColors.gold : const Color(0xFFB45309),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (list.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          list.description,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${list.items.length} ${list.items.length == 1 ? "Scripture" : "Scriptures"}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _playListDirectly(list),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? ImagoColors.gold : const Color(0xFF4F46E5)).withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
