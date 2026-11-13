// lib/screens/bible_list_detail_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_data_models.dart';
import '../services/user_data_service.dart';
import '../services/bible_service.dart';
import '../services/playlist_player_service.dart';
import '../widgets/scripture_playlist_player_sheet.dart';
import '../theme/imago_theme.dart';

class BibleListDetailScreen extends StatefulWidget {
  final int listId;

  const BibleListDetailScreen({super.key, required this.listId});

  @override
  State<BibleListDetailScreen> createState() => _BibleListDetailScreenState();
}

class _BibleListDetailScreenState extends State<BibleListDetailScreen> {
  BibleList? _bibleList;
  bool _isLoading = true;
  bool _isResolvingPlaylist = false;

  @override
  void initState() {
    super.initState();
    _loadListDetails();
  }

  Future<void> _loadListDetails() async {
    setState(() => _isLoading = true);
    final list = await UserDataService.instance.getBibleListWithItems(widget.listId);
    if (mounted) {
      setState(() {
        _bibleList = list;
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

  Future<void> _playEntirePlaylist() async {
    if (_bibleList == null || _bibleList!.items.isEmpty) return;

    setState(() => _isResolvingPlaylist = true);

    final List<BiblePlaylistItem> playlistItems = [];
    for (final item in _bibleList!.items) {
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

    if (!mounted) return;
    setState(() => _isResolvingPlaylist = false);

    if (playlistItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not resolve scriptures for audio lineup.')),
      );
      return;
    }

    await PlaylistPlayerService.instance.loadPlaylist(
      _bibleList!.title,
      playlistItems,
      autoPlay: true,
    );

    if (mounted) {
      ScripturePlaylistPlayerSheet.show(context);
    }
  }

  Future<void> _showAddScriptureDialog() async {
    final isDark = ImagoColors.isDark;
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? ImagoColors.surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0)),
        ),
        title: Text(
          'Add Scriptures',
          style: TextStyle(
            fontFamily: 'Cinzel',
            color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter scripture references (separated by commas or newlines). E.g.: John 3:16, Psalm 23, Romans 8:28-31',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: isDark ? ImagoColors.secondaryText : const Color(0xFF475569),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              maxLines: 3,
              style: TextStyle(color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A), fontFamily: 'Poppins'),
              decoration: InputDecoration(
                hintText: 'e.g. Psalm 91\nPhilippians 4:6-7\nIsaiah 40:31',
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final raw = textController.text.trim();
              if (raw.isEmpty) return;

              final refs = BibleService.instance.extractScriptureReferences(raw);
              if (refs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No valid scripture references recognized.')),
                );
                return;
              }

              for (final r in refs) {
                await UserDataService.instance.addScriptureToList(widget.listId, r);
              }
              Navigator.pop(ctx);
              _loadListDetails();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add to Lineup', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(BibleListItem item) async {
    if (item.id != null) {
      await UserDataService.instance.deleteListItem(item.id!, widget.listId);
      _loadListDetails();
    }
  }

  Future<void> _deleteList() async {
    final isDark = ImagoColors.isDark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? ImagoColors.surface : Colors.white,
        title: Text('Delete List?', style: TextStyle(fontFamily: 'Cinzel', color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this Bible list and its lineup?', style: TextStyle(color: isDark ? ImagoColors.secondaryText : const Color(0xFF475569))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await UserDataService.instance.deleteBibleList(widget.listId);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        final isDark = ImagoColors.isDark;

        if (_isLoading) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: CircularProgressIndicator(
                color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
              ),
            ),
          );
        }

        if (_bibleList == null) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: Center(
              child: Text(
                'List not found',
                style: TextStyle(
                  color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        }

        final accentColor = _parseColor(_bibleList!.colorHex);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              CosmicBackground(children: const []),
              Positioned(
                top: -50,
                right: -50,
                child: CosmicOrb(
                  size: 280,
                  color: accentColor,
                  opacity: isDark ? 0.1 : 0.06,
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(accentColor, isDark),
                    Expanded(
                      child: _bibleList!.items.isEmpty
                          ? _buildEmptyState(isDark)
                          : _buildItemsList(accentColor, isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _bibleList!.items.isNotEmpty
              ? _buildPlayBottomBar(accentColor, isDark)
              : null,
        );
      },
    );
  }

  Widget _buildHeader(Color accentColor, bool isDark) {
    final canPop = Navigator.canPop(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? ImagoColors.cardBackground : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (canPop)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? ImagoColors.cardBackground : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? ImagoColors.borderColor : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A),
                      size: 16,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.add_rounded,
                      color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
                    ),
                    onPressed: _showAddScriptureDialog,
                  ),
                  if (!_bibleList!.isPreset)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: isDark ? ImagoColors.secondaryText : const Color(0xFF94A3B8),
                      ),
                      onPressed: _deleteList,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _bibleList!.title,
            style: TextStyle(
              fontFamily: 'Cinzel',
              color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_bibleList!.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _bibleList!.description,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: isDark ? ImagoColors.secondaryText : const Color(0xFF475569),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? accentColor.withOpacity(0.15) : accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? accentColor.withOpacity(0.35) : accentColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '${_bibleList!.items.length} ${_bibleList!.items.length == 1 ? "Scripture" : "Scriptures"}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(Color accentColor, bool isDark) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _bibleList!.items.length,
      onReorder: (oldIndex, newIndex) async {
        if (newIndex > oldIndex) newIndex -= 1;
        final items = List<BibleListItem>.from(_bibleList!.items);
        final movedItem = items.removeAt(oldIndex);
        items.insert(newIndex, movedItem);

        setState(() {
          _bibleList = _bibleList!.copyWith(items: items);
        });

        final itemIds = items.map((e) => e.id!).toList();
        await UserDataService.instance.reorderListItems(widget.listId, itemIds);
      },
      itemBuilder: (context, index) {
        final item = _bibleList!.items[index];

        return Dismissible(
          key: ValueKey(item.id ?? index),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.only(right: 20),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
          ),
          onDismissed: (_) => _deleteItem(item),
          child: Container(
            key: ValueKey(item.id ?? index),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? ImagoColors.cardBackground : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? accentColor.withOpacity(0.15) : accentColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.reference,
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.customTitle.isNotEmpty)
                        Text(
                          item.customTitle,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.play_circle_outline_rounded,
                    color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
                    size: 28,
                  ),
                  onPressed: () async {
                    final verses = await BibleService.instance.getVerseByReference(item.reference);
                    if (verses.isNotEmpty && mounted) {
                      await PlaylistPlayerService.instance.loadPlaylist(
                        _bibleList!.title,
                        [
                          BiblePlaylistItem(
                            reference: item.reference,
                            displayTitle: item.reference,
                            verses: verses,
                          )
                        ],
                        autoPlay: true,
                      );
                      ScripturePlaylistPlayerSheet.show(context);
                    }
                  },
                ),
                Icon(
                  Icons.drag_handle_rounded,
                  color: isDark ? ImagoColors.secondaryText.withOpacity(0.5) : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_add_rounded,
            size: 64,
            color: isDark ? ImagoColors.secondaryText.withOpacity(0.3) : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          Text(
            'No scriptures in this list yet',
            style: TextStyle(
              fontFamily: 'Cinzel',
              color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showAddScriptureDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Scripture'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? ImagoColors.violet : const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayBottomBar(Color accentColor, bool isDark) {
    final btnBg = isDark ? ImagoColors.gold : const Color(0xFF4F46E5);
    final btnFg = isDark ? Colors.black : Colors.white;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: isDark ? ImagoColors.surface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isResolvingPlaylist ? null : _playEntirePlaylist,
        icon: _isResolvingPlaylist
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: btnFg),
              )
            : Icon(Icons.play_arrow_rounded, color: btnFg, size: 28),
        label: Text(
          _isResolvingPlaylist ? 'Preparing Lineup...' : 'Play Playlist Lineup',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: btnFg,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: btnBg,
          elevation: isDark ? 8 : 3,
          shadowColor: isDark ? Colors.transparent : const Color(0xFF4F46E5).withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
