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

  // ✅ Add로 넘길 선택 날짜
  DateTime? _selectedDate;

  // id -> {offset, scale}
  final Map<String, _CanvasItemState> _canvasItems = {};

  // ✅ 이미지 로딩 완료 플래그 (캡처 시 회색 방지)
  bool _imagesReady = false;

  // ✅ 캡처 순간에만 편집 UI 숨김(테두리/삭제 버튼/리사이즈 핸들)
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();

    final data = widget.extra as Map<String, dynamic>?;

    clothesIds = (data?['clothesIds'] as List<dynamic>? ?? []).cast<String>();

    final Map<String, dynamic> imageUrlsRaw =
    (data?['imageUrls'] as Map<String, dynamic>? ?? {});
    imageUrls = imageUrlsRaw.map((k, v) => MapEntry(k, v.toString()));

    // ✅ Calendar/이전 화면에서 선택한 날짜를 같이 넘겨받는 구조
    final dt = data?['selectedDate'];
    if (dt is DateTime) {
      _selectedDate = DateTime(dt.year, dt.month, dt.day);
    }

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
      // ✅ 캡처 순간에만 편집 UI 숨김
      setState(() => _isCapturing = true);

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

  Future<void> _goToAddSchedule() async {
    final selected = _canvasItems.keys.toList();

    if (selected.isEmpty) {
      _showTempSnack('캔버스에 남은 옷이 없습니다.');
      return;
    }

    if (!_imagesReady) {
      _showTempSnack('이미지 로딩 중입니다.');
      return;
    }

    final pngBytes = await _captureCanvasPng();
    if (pngBytes == null || pngBytes.isEmpty) {
      _showTempSnack('캡처 실패(빈 이미지)');
      return;
    }

    debugPrint('COMBINE pngBytes length = ${pngBytes.length}');

    context.pop({
      'action': 'registerToSchedule',
      'selectedDate': _selectedDate ?? DateTime.now(),
      'canvasPngBytes': pngBytes,
      'clothesIds': selected,
      'imageUrls': imageUrls,
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
                  // ✅ 저장 이미지 배경도 깔끔하게 흰색
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
                            hideControls: _isCapturing, // ✅ 캡처 시 숨김
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
                      '룩북에 저장하기',
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
                        : _goToAddSchedule,
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
                      !_imagesReady ? '이미지 로딩중...' : '코디 생성 완료',
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
    required this.hideControls,
    required this.onMove,
    required this.onScale,
    required this.onRemove,
  });

  final String id;
  final String imageUrl;
  final double scale;

  // ✅ 캡처 중이면 테두리/삭제 버튼/리사이즈 핸들 숨김
  final bool hideControls;

  final void Function(Offset delta) onMove;
  final void Function(double nextScale) onScale;
  final VoidCallback onRemove;

  @override
  State<_DraggableCanvasItem> createState() => _DraggableCanvasItemState();
}

class _DraggableCanvasItemState extends State<_DraggableCanvasItem> {
  double? _startScale;

  // ✅ 모서리 드래그로 스케일 조절(최소 변경, 비율 고정)
  void _onResizeDrag(DragUpdateDetails d) {
    final delta = d.delta.dx - d.delta.dy; // 대각선 느낌
    final next = (widget.scale + delta * 0.006).clamp(0.6, 1.8);
    widget.onScale(next);
  }

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
                border: widget.hideControls
                    ? null
                    : Border.all(color: const Color(0xFF7B5CFF), width: 2),
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

          // ✅ 삭제 버튼 (캡처 시 숨김)
          if (!widget.hideControls)
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

          // ✅ 우하단 리사이즈 핸들 (캡처 시 숨김)
          if (!widget.hideControls)
            Positioned(
              right: -6,
              bottom: -6,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: _onResizeDrag,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.open_in_full, size: 10, color: Colors.black),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
