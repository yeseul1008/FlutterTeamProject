import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class QuestionClosetResult extends StatefulWidget {
  const QuestionClosetResult({super.key, required this.extra});

  final Object? extra;

  @override
  State<QuestionClosetResult> createState() => _QuestionClosetResultState();
}

class _QuestionClosetResultState extends State<QuestionClosetResult> {
  final GlobalKey _canvasKey = GlobalKey();

  late final String postId;
  late final List<String> clothesIds;
  late final Map<String, String> imageUrls;

  final Map<String, _CanvasItemState> _canvasItems = {};
  bool _imagesReady = false;
  bool _isCapturing = false;
  bool _isUploadingComment = false;

  @override
  void initState() {
    super.initState();

    final data = widget.extra as Map<String, dynamic>?;

    postId = data?['postId'] ?? '';
    clothesIds = (data?['clothesIds'] as List<dynamic>? ?? []).cast<String>();
    final Map<String, dynamic> imageUrlsRaw =
    (data?['imageUrls'] as Map<String, dynamic>? ?? {});
    imageUrls = imageUrlsRaw.map((k, v) => MapEntry(k, v.toString()));

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

  Future<void> _saveCommentToPost() async {
    if (_isUploadingComment) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showTempSnack('로그인이 필요합니다.');
      return;
    }

    if (_canvasItems.isEmpty) {
      _showTempSnack('캔버스에 남은 옷이 없습니다.');
      return;
    }

    if (!_imagesReady) {
      _showTempSnack('이미지 로딩 중입니다.');
      return;
    }

    final TextEditingController commentController = TextEditingController();
    final commentText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 입력'),
        content: TextField(
          controller: commentController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '댓글 내용을 입력하세요'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, commentController.text.trim()),
            child: const Text('등록'),
          ),
        ],
      ),
    );

    if (commentText == null || commentText.isEmpty) return;

    setState(() => _isUploadingComment = true);

    try {
      final pngBytes = await _captureCanvasPng();
      if (pngBytes == null || pngBytes.isEmpty) {
        _showTempSnack('이미지 캡처 실패');
        return;
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('commentImg/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.png');
      final uploadTask = storageRef.putData(pngBytes);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final commentRef = FirebaseFirestore.instance
          .collection('questions')
          .doc(postId)
          .collection('qna_comments')
          .doc();

      await commentRef.set({
        'comment': commentText,
        'commentImg': downloadUrl,
        'authorId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showTempSnack('댓글이 등록되었습니다.');
      Navigator.pop(context);
      Navigator.pop(context);
    } catch (e) {
      _showTempSnack('댓글 등록 실패');
      debugPrint('댓글 업로드 에러: $e');
    } finally {
      if (mounted) setState(() => _isUploadingComment = false);
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
                              borderRadius:
                              BorderRadius.all(Radius.circular(10)),
                            ),
                            child: Padding(
                              padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                            onMove: (delta) {
                              setState(() {
                                final cur = _canvasItems[id];
                                if (cur == null) return;
                                _canvasItems[id] =
                                    cur.copyWith(offset: cur.offset + delta);
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
                            onRemove: () {
                              setState(() => _canvasItems.remove(id));
                            },
                            onTap: () {
                              setState(() {
                                final tapped = _canvasItems.remove(id);
                                if (tapped != null) _canvasItems[id] = tapped;
                              });
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
                    onPressed: (_canvasItems.isEmpty ||
                        !_imagesReady ||
                        _isUploadingComment)
                        ? null
                        : _saveCommentToPost,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _isUploadingComment ? '업로드 중...' : '댓글 추가하기',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 12),
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

// CanvasItem 상태
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

// DraggableCanvasItem
class _DraggableCanvasItem extends StatefulWidget {
  const _DraggableCanvasItem({
    required this.id,
    required this.imageUrl,
    required this.scale,
    required this.hideControls,
    required this.onMove,
    required this.onScale,
    required this.onRemove,
    this.onTap,
  });

  final String id;
  final String imageUrl;
  final double scale;
  final bool hideControls;
  final void Function(Offset delta) onMove;
  final void Function(double nextScale) onScale;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

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
      onTap: widget.onTap,
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
                color: Colors.white,
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
                            child: Icon(
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
