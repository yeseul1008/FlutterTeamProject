import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../firebase/firestore_service.dart';

final FirestoreService _firestoreService = FirestoreService();

class lookbookCombine extends StatefulWidget {
  const lookbookCombine({super.key, required this.extra});
  final Object? extra;

  @override
  State<lookbookCombine> createState() => _LookbookCombineState();
}

class _LookbookCombineState extends State<lookbookCombine> {
  final GlobalKey _canvasKey = GlobalKey();

  late final List<String> clothesIds;
  late final Map<String, String> imageUrls;

  DateTime? _selectedDate;
  final Map<String, _CanvasItemState> _canvasItems = {};
  bool _imagesReady = false;
  bool _isCapturing = false;
  bool _isSavingLookbook = false;

  @override
  void initState() {
    super.initState();

    final data = widget.extra as Map<String, dynamic>?;

    clothesIds = (data?['clothesIds'] as List<dynamic>? ?? []).cast<String>();
    final Map<String, dynamic> imageUrlsRaw =
    (data?['imageUrls'] as Map<String, dynamic>? ?? {});
    imageUrls = imageUrlsRaw.map((k, v) => MapEntry(k, v.toString()));

    final dt = data?['selectedDate'];
    if (dt is DateTime) {
      _selectedDate = DateTime(dt.year, dt.month, dt.day);
    }

    for (int i = 0; i < clothesIds.length; i++) {
      final id = clothesIds[i];
      _canvasItems[id] = _CanvasItemState(
        offset: Offset(12.0 + (i % 3) * 56.0, 12.0 + (i ~/ 3) * 72.0),
        scale: 1.0,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAll();
    });
  }

  Future<void> _precacheAll() async {
    final urls = clothesIds
        .map((id) => imageUrls[id])
        .where((u) => u != null && u!.isNotEmpty)
        .cast<String>()
        .toList();

    try {
      for (final u in urls) {
        await precacheImage(NetworkImage(u), context);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _imagesReady = true);
  }

  Future<Uint8List?> _captureCanvasPng() async {
    try {
      setState(() => _isCapturing = true);
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
      _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }


  void _resetLayout() {
    setState(() {
      _canvasItems.clear();
      for (int i = 0; i < clothesIds.length; i++) {
        final id = clothesIds[i];
        _canvasItems[id] = _CanvasItemState(
          offset: Offset(12.0 + (i % 3) * 56.0, 12.0 + (i ~/ 3) * 72.0),
          scale: 1.0,
        );
      }
    });
  }

  void _showTempSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }

  // ✅ 클릭 시 최상단으로
  void _bringToFront(String id) {
    if (!_canvasItems.containsKey(id)) return;
    setState(() {
      final item = _canvasItems.remove(id)!;
      _canvasItems[id] = item; // 마지막 = 최상단
    });
  }

  Future<String?> _askLookbookAlias() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white, // 배경 하얀색
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '룩북 이름',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 30,
                  decoration: InputDecoration(
                    hintText: '예) 놀이공원 코디',
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black), // 기본 테두리
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black), // 포커스 테두리
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black, // 글자 색 검정
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final alias = controller.text.trim();
                        if (alias.isEmpty) return;
                        Navigator.pop(ctx, alias);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCAD83B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text(
                        '저장',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

      },
    );

    return result?.trim().isEmpty == true ? null : result?.trim();
  }

  Future<void> _saveToLookbook() async {
    if (_isSavingLookbook) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showTempSnack('로그인이 필요합니다.');
      return;
    }

    final selected = _canvasItems.keys.toList();
    if (selected.isEmpty) {
      _showTempSnack('캔버스에 남은 옷이 없습니다.');
      return;
    }

    if (!_imagesReady) {
      _showTempSnack('이미지 로딩 중입니다.');
      return;
    }

    final alias = await _askLookbookAlias();
    if (alias == null || alias.isEmpty) return;

    setState(() => _isSavingLookbook = true);

    try {
      final pngBytes = await _captureCanvasPng();
      if (pngBytes == null || pngBytes.isEmpty) {
        _showTempSnack('캡처 실패(빈 이미지)');
        return;
      }

      final resultImageUrl = await _firestoreService.uploadLookbookCanvasPng(
        userId: user.uid,
        pngBytes: pngBytes,
      );

      await _firestoreService.createLookbookWithFlag(
        userId: user.uid,
        alias: alias,
        resultImageUrl: resultImageUrl,
        clothesIds: selected,
        inLookbook: true,
        publishToCommunity: false,
      );

      _showTempSnack('룩북에 저장되었습니다.');
      if (mounted) {
        context.go('/userLookbook');
      }
    } catch (_) {
      _showTempSnack('룩북 저장 실패');
    } finally {
      if (mounted) setState(() => _isSavingLookbook = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAny = clothesIds.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '조합하기',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: '초기화',
            onPressed: hasAny ? _resetLayout : null,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: !hasAny
          ? const Center(child: Text('선택된 옷이 없습니다.'))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: RepaintBoundary(
              key: _canvasKey,
              child: Container(
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      if (_canvasItems.isEmpty)
                        const Center(
                          child: Text(
                            '캔버스에 남아있는 옷이 없습니다.\nX로 지운 경우 초기화로 되돌릴 수 있어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      if (!_imagesReady)
                        const Positioned(
                          left: 12,
                          top: 12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Text(
                                '이미지 불러오는 중...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ..._canvasItems.entries.map((e) {
                        final id = e.key;
                        final state = e.value;
                        final url = imageUrls[id] ?? '';
                        if (url.isEmpty) return const SizedBox.shrink();

                        return Positioned(
                          left: state.offset.dx,
                          top: state.offset.dy,
                          child: _DraggableCanvasItem(
                            id: id,
                            imageUrl: url,
                            scale: state.scale,
                            hideControls: _isCapturing,
                            onBringToFront: () => _bringToFront(id),
                            onMove: (delta) {
                              setState(() {
                                final cur = _canvasItems[id];
                                if (cur == null) return;
                                _canvasItems[id] = cur.copyWith(
                                  offset: cur.offset + delta,
                                );
                              });
                            },
                            onScale: (nextScale) {
                              setState(() {
                                final cur = _canvasItems[id];
                                if (cur == null) return;
                                _canvasItems[id] =
                                    cur.copyWith(scale: nextScale.clamp(0.6, 1.8));
                              });
                            },
                            onRemove: () => setState(() => _canvasItems.remove(id)),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_canvasItems.isEmpty || !_imagesReady || _isSavingLookbook)
                        ? null
                        : _saveToLookbook,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _isSavingLookbook ? '저장 중...' : '룩북에 저장하기',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// CanvasItem & DraggableCanvasItem
class _CanvasItemState {
  final Offset offset;
  final double scale;

  const _CanvasItemState({required this.offset, this.scale = 1.0});

  _CanvasItemState copyWith({Offset? offset, double? scale}) {
    return _CanvasItemState(
      offset: offset ?? this.offset,
      scale: scale ?? this.scale,
    );
  }
}

class _DraggableCanvasItem extends StatefulWidget {
  const _DraggableCanvasItem({
    required this.id,
    required this.imageUrl,
    required this.scale,
    required this.hideControls,
    required this.onMove,
    required this.onScale,
    required this.onRemove,
    this.onBringToFront,
  });

  final String id;
  final String imageUrl;
  final double scale;
  final bool hideControls;
  final void Function(Offset delta) onMove;
  final void Function(double nextScale) onScale;
  final VoidCallback onRemove;
  final VoidCallback? onBringToFront;

  @override
  State<_DraggableCanvasItem> createState() => _DraggableCanvasItemState();
}

class _DraggableCanvasItemState extends State<_DraggableCanvasItem> {
  double? _startScale;

  static const double _baseW = 92;
  static const double _baseH = 120;

  void _onResizeDrag(DragUpdateDetails d) {
    final delta = d.delta.dx + d.delta.dy;
    final next = (widget.scale + delta * 0.006).clamp(0.6, 1.8);
    widget.onScale(next);
  }

  @override
  Widget build(BuildContext context) {
    final w = _baseW * widget.scale;
    final h = _baseH * widget.scale;

    return GestureDetector(
      onTapDown: (_) => widget.onBringToFront?.call(),
      onScaleStart: (_) => _startScale = widget.scale,
      onScaleUpdate: (details) {
        if (details.focalPointDelta != Offset.zero) {
          widget.onMove(details.focalPointDelta);
        }
        if (details.pointerCount >= 2 && _startScale != null) {
          widget.onScale((_startScale! * details.scale).clamp(0.6, 1.8));
        }
      },
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                border: widget.hideControls
                    ? null
                    : Border.all(color: const Color(0xFF7B5CFF), width: 2),
                borderRadius: BorderRadius.circular(10),
                color: Colors.transparent,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(widget.imageUrl, fit: BoxFit.cover),
              ),
            ),
            if (!widget.hideControls)
              Positioned(
                right: -10,
                top: -10,
                child: InkWell(
                  onTap: widget.onRemove,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            if (!widget.hideControls)
              Positioned(
                right: -10,
                bottom: -10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: _onResizeDrag,
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: 1.6,
                            child: const Icon(
                              Icons.open_in_full,
                              size: 12,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
