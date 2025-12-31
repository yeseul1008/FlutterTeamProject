import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

class ScheduleCombine extends StatefulWidget {
  const ScheduleCombine({super.key, required this.extra});

  final Object? extra;

  @override
  State<ScheduleCombine> createState() => _ScheduleCombineState();
}

class _ScheduleCombineState extends State<ScheduleCombine> {
  final GlobalKey _canvasKey = GlobalKey();

  late final List<String> clothesIds;
  late final Map<String, String> imageUrls;

  // id -> {offset, scale}
  final Map<String, _CanvasItemState> _canvasItems = {};

  // ✅ 이미지 로딩 완료 플래그 (캡처 시 회색 방지)
  bool _imagesReady = false;

  @override
  void initState() {
    super.initState();

    final data = widget.extra as Map<String, dynamic>?;

    clothesIds = (data?['clothesIds'] as List<dynamic>? ?? []).cast<String>();

    final Map<String, dynamic> imageUrlsRaw =
    (data?['imageUrls'] as Map<String, dynamic>? ?? {});
    imageUrls = imageUrlsRaw.map((k, v) => MapEntry(k, v.toString()));

    // ✅ 전부 캔버스에 자동 배치
    for (int i = 0; i < clothesIds.length; i++) {
      final id = clothesIds[i];
      _canvasItems[id] = _CanvasItemState(
        offset: Offset(12.0 + (i % 3) * 56.0, 12.0 + (i ~/ 3) * 72.0),
        scale: 1.0,
      );
    }

    // ✅ context 안전 + 첫 paint 이후에 precache
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
    } catch (_) {
      // 일부 실패해도 진행
    }

    if (!mounted) return;
    setState(() => _imagesReady = true);
  }

  Future<Uint8List?> _captureCanvasPng() async {
    try {
      // ✅ paint 완료 보장 (모바일에서 회색 방지 핵심)
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
      _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      if (boundary.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
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

  Future<void> _registerToSchedule() async {
    final selected = _canvasItems.keys.toList();

    final pngBytes = await _captureCanvasPng();
    if (pngBytes == null || pngBytes.isEmpty) {
      _showTempSnack('캡처 실패(빈 이미지)');
      return;
    }

    context.pop({
      'action': 'registerToSchedule',
      'clothesIds': selected,
      'canvasPngBytes': pngBytes,
    });
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
                  color: const Color(0xFFF5F5F7),
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
                                _canvasItems[id] = cur.copyWith(
                                  scale: nextScale.clamp(0.6, 1.8),
                                );
                              });
                            },
                            onRemove: () {
                              setState(() => _canvasItems.remove(id));
                            },
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
                    onPressed: () => _showTempSnack('AI생성 결과 보기는 추후 연결'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'AI생성 결과 보기',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showTempSnack('코디로 저장하기는 추후 연결'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      '코디로 저장하기',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_canvasItems.isEmpty || !_imagesReady)
                        ? null
                        : _registerToSchedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCAD83B),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.black),
                      ),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      !_imagesReady ? '이미지 로딩중...' : '일정에 등록하기',
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

class _CanvasItemState {
  final Offset offset;
  final double scale;

  const _CanvasItemState({
    required this.offset,
    this.scale = 1.0,
  });

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
    required this.onMove,
    required this.onScale,
    required this.onRemove,
  });

  final String id;
  final String imageUrl;
  final double scale;
  final void Function(Offset delta) onMove;
  final void Function(double nextScale) onScale;
  final VoidCallback onRemove;

  @override
  State<_DraggableCanvasItem> createState() => _DraggableCanvasItemState();
}

class _DraggableCanvasItemState extends State<_DraggableCanvasItem> {
  double? _startScale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (_) => _startScale = widget.scale,
      onScaleUpdate: (details) {
        if (details.focalPointDelta != Offset.zero) {
          widget.onMove(details.focalPointDelta);
        }
        if (details.pointerCount >= 2 && _startScale != null) {
          widget.onScale(_startScale! * details.scale);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.scale(
            scale: widget.scale,
            alignment: Alignment.topLeft,
            child: Container(
              width: 92,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF7B5CFF), width: 2),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            right: -8,
            top: -8,
            child: InkWell(
              onTap: widget.onRemove,
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
        ],
      ),
    );
  }
}
