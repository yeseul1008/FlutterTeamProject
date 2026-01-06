import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase/firestore_service.dart';

final FirestoreService _firestoreService = FirestoreService();

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

  DateTime? _selectedDate;

  // id -> {offset, scale}
  final Map<String, _CanvasItemState> _canvasItems = {};

  bool _imagesReady = false;
  bool _isCapturing = false;
  bool _isSavingLookbook = false;

  // 튜토리얼 타겟 키
  final GlobalKey _tutorialCanvasKey = GlobalKey();
  final GlobalKey _tutorialResetKey = GlobalKey();
  final GlobalKey _tutorialSaveLookbookKey = GlobalKey();
  final GlobalKey _tutorialCompleteKey = GlobalKey();
  final GlobalKey _tutorialFirstDeleteKey = GlobalKey();
  final GlobalKey _tutorialFirstResizeKey = GlobalKey();

  TutorialCoachMark? _tutorialCoachMark;

  @override
  void initState() {
    super.initState();

    final data = widget.extra as Map<String, dynamic>?;

    clothesIds = (data?['clothesIds'] as List<dynamic>? ?? []).cast<String>();

    final Map<String, dynamic> imageUrlsRaw =
    (data?['imageUrls'] as Map<String, dynamic>? ?? {});
    imageUrls = imageUrlsRaw.map((k, v) => MapEntry(k, v.toString()));

    final dt = data?['selectedDate'];
    if (dt is DateTime) _selectedDate = DateTime(dt.year, dt.month, dt.day);

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

    await _checkAndShowTutorialOnce();
  }

  Future<void> _checkAndShowTutorialOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('hasSeenCombineTutorial') ?? false;
      if (hasSeen) return;

      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      _showTutorial();
      await prefs.setBool('hasSeenCombineTutorial', true);
    } catch (_) {}
  }

  void _showTutorial() {
    _tutorialCoachMark?.finish();

    _tutorialCoachMark = TutorialCoachMark(
      targets: _createTutorialTargets(),
      colorShadow: Colors.black,
      opacityShadow: 0.82,
      paddingFocus: 10,
      textSkip: "Skip",
      onSkip: () {
        return true;
      },
    );

    _tutorialCoachMark?.show(context: context);
  }

  List<TargetFocus> _createTutorialTargets() {
    final List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: 'combine-canvas',
        keyTarget: _tutorialCanvasKey,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Container(
                padding: const EdgeInsets.all(18),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '캔버스에서 옷 배치하기',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '한 손가락으로 드래그해서 위치를 옮길 수 있어요.\n두 손가락으로 확대/축소도 가능해요.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: 'combine-delete',
        keyTarget: _tutorialFirstDeleteKey,
        shape: ShapeLightFocus.Circle,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Container(
                padding: const EdgeInsets.all(18),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '삭제 버튼',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'X를 누르면 해당 옷을 캔버스에서 제거합니다.\n실수로 지웠다면 초기화로 되돌릴 수 있어요.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: 'combine-resize',
        keyTarget: _tutorialFirstResizeKey,
        shape: ShapeLightFocus.Circle,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Container(
                padding: const EdgeInsets.all(18),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '사이즈 조절',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '오른쪽 아래 아이콘을 드래그하면 크기를 조절할 수 있어요.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: 'combine-reset',
        keyTarget: _tutorialResetKey,
        shape: ShapeLightFocus.Circle,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Container(
                padding: const EdgeInsets.all(18),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '초기화',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '배치가 엉켰다면 초기화로 기본 배치로 되돌릴 수 있어요.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: 'combine-save-lookbook',
        keyTarget: _tutorialSaveLookbookKey,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Container(
                padding: const EdgeInsets.all(18),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '룩북 저장',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '현재 코디를 룩북으로 저장할 수 있어요.\n이름을 입력하면 이미지가 저장됩니다.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: 'combine-complete',
        keyTarget: _tutorialCompleteKey,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Container(
                padding: const EdgeInsets.all(18),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '코디 생성 완료',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '완성되면 이 버튼을 눌러서 Add로 돌아가\n일정 등록을 이어서 진행합니다.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    return targets;
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

  // 캔버스영역 : 터치 시 해당 사진 레이어 최상단
  void _bringToFront(String id) {
    if (!_canvasItems.containsKey(id)) return;
    setState(() {
      final v = _canvasItems.remove(id)!;
      _canvasItems[id] = v;
    });
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

    context.pop({
      'action': 'registerToSchedule',
      'selectedDate': _selectedDate ?? DateTime.now(),
      'canvasPngBytes': pngBytes,
      'clothesIds': selected,
      'imageUrls': imageUrls,
    });
  }

  Future<String?> _askLookbookAlias() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('룩북 이름', style: TextStyle(fontWeight: FontWeight.w900)),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            decoration: const InputDecoration(
              hintText: '예) 오늘의 코디',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final alias = controller.text.trim();
                if (alias.isEmpty) return;
                Navigator.pop(ctx, alias);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    final v = result?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
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
    if (alias == null) return;

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
    } catch (_) {
      _showTempSnack('룩북 저장 실패');
    } finally {
      if (mounted) setState(() => _isSavingLookbook = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAny = clothesIds.isNotEmpty;

    final String? firstId = _canvasItems.isEmpty ? null : _canvasItems.keys.first;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
            tooltip: '사용법',
            onPressed: hasAny ? _showTutorial : null,
            icon: const Icon(Icons.help_outline, color: Colors.black),
          ),
          IconButton(
            key: _tutorialResetKey,
            tooltip: '초기화',
            onPressed: hasAny ? _resetLayout : null,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: !hasAny
          ? const Center(child: Text('선택된 옷이 없습니다.'))
          : Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: RepaintBoundary(
            key: _canvasKey,
            child: Container(
              key: _tutorialCanvasKey,
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: _isCapturing ? null : Border.all(color: Colors.black, width: 1.2),
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

                      final bool isFirstTarget = (firstId != null && id == firstId);

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
                              _canvasItems[id] = cur.copyWith(offset: cur.offset + delta);
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
                          onRemove: () => setState(() => _canvasItems.remove(id)),
                          deleteKey: isFirstTarget ? _tutorialFirstDeleteKey : null,
                          resizeKey: isFirstTarget ? _tutorialFirstResizeKey : null,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: _tutorialSaveLookbookKey,
                  onPressed: (_canvasItems.isEmpty || !_imagesReady || _isSavingLookbook)
                      ? null
                      : _saveToLookbook,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _isSavingLookbook ? '저장 중...' : '룩북에 저장하기',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  key: _tutorialCompleteKey,
                  onPressed: (_canvasItems.isEmpty || !_imagesReady) ? null : _goToAddSchedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCAD83B),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Colors.black, width: 1.2),
                    ),
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
      ),
    );
  }
}

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
    required this.onBringToFront,
    required this.onMove,
    required this.onScale,
    required this.onRemove,
    this.deleteKey,
    this.resizeKey,
  });

  final String id;
  final String imageUrl;
  final double scale;
  final bool hideControls;

  final VoidCallback onBringToFront;
  final void Function(Offset delta) onMove;
  final void Function(double nextScale) onScale;
  final VoidCallback onRemove;

  final GlobalKey? deleteKey;
  final GlobalKey? resizeKey;

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
      onTapDown: (_) => widget.onBringToFront(),
      onScaleStart: (_) {
        widget.onBringToFront();
        _startScale = widget.scale;
      },
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

            // 삭제 버튼
            if (!widget.hideControls)
              Positioned(
                right: -10,
                top: -10,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Center(
                    child: InkWell(
                      key: widget.deleteKey,
                      borderRadius: BorderRadius.circular(999),
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
                ),
              ),

            // 캔버스에서 개별 사진 사이즈 조절 버튼
            if (!widget.hideControls)
              Positioned(
                right: -10,
                bottom: -10,
                child: GestureDetector(
                  key: widget.resizeKey,
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => widget.onBringToFront(),
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

