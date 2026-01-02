import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/common/weatherWidget.dart';
import '../../service/kakao/kakao_models.dart';
import '../../firebase/firestore_service.dart';

class UserScheduleAdd extends StatefulWidget {
  const UserScheduleAdd({super.key});

  @override
  State<UserScheduleAdd> createState() => _UserScheduleAddState();
}

class _UserScheduleAddState extends State<UserScheduleAdd> {
  static const String _openWeatherApiKey = '5ebe456d15b6fd5e52fbf09d1ab110ae';

  final FirestoreService _firestoreService = FirestoreService();

  // ===== mode =====
  String _mode = 'create'; // create | edit
  String? _scheduleId;

  // ===== inputs =====
  DateTime _selectedDate = DateTime.now();
  String? _placeName;
  double _lat = 37.5665;
  double _lon = 126.9780;
  String? _scheduleText;

  // ===== preview (edit에서는 URL로) =====
  String? _previewImageUrl; // ✅ edit 진입 시 calendar.imageURL로 세팅

  // ===== 룩북 선택 =====
  String? _selectedLookbookId;

  // ===== combine draft =====
  Uint8List? _canvasPngBytes;
  List<String> _clothesIds = [];
  Map<String, String> _imageUrls = {};

  bool _isSaving = false;
  bool _inited = false;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateKey(DateTime d) {
    final day = _dateOnly(d);
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime d) {
    final w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
    return '${d.year}.${d.month}.${d.day} $w';
  }

  Future<void> _loadCalendarPreviewIfEdit() async {
    if (_mode != 'edit') return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final key = _dateKey(_selectedDate);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('calendar')
          .doc(key)
          .get();

      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;

      final url = (data['imageURL'] ?? '').toString().trim();

      final dest = (data['destinationName'] ?? '').toString();
      final plan = (data['planText'] ?? '').toString();
      final geo = data['destination'];
      final lookbookId = (data['lookbookId'] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        if (url.isNotEmpty) _previewImageUrl = url;
        if (lookbookId.isNotEmpty) _selectedLookbookId = lookbookId;

        if ((_placeName == null || _placeName!.isEmpty) && dest.isNotEmpty) {
          _placeName = dest;
        }
        if ((_scheduleText == null || _scheduleText!.isEmpty) && plan.isNotEmpty) {
          _scheduleText = plan;
        }

        if (geo is GeoPoint) {
          _lat = geo.latitude;
          _lon = geo.longitude;
        }
      });
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      final String? mode = extra['mode']?.toString();
      if (mode == 'edit') {
        _mode = 'edit';
      } else if (mode == 'create') {
        _mode = 'create';
      }

      final dt = extra['selectedDate'];
      if (dt is DateTime) _selectedDate = _dateOnly(dt);

      _scheduleId = extra['scheduleId']?.toString();

      _placeName = extra['destinationName']?.toString() ?? _placeName;
      _scheduleText = extra['planText']?.toString() ?? _scheduleText;

      final lat = extra['lat'];
      final lon = extra['lon'];
      if (lat is num) _lat = lat.toDouble();
      if (lon is num) _lon = lon.toDouble();

      final bytes = extra['canvasPngBytes'];
      if (bytes is Uint8List) _canvasPngBytes = bytes;

      final ci = extra['clothesIds'];
      if (ci is List) _clothesIds = ci.cast<String>();

      final iu = extra['imageUrls'];
      if (iu is Map) {
        _imageUrls = iu.map((k, v) => MapEntry(k.toString(), v.toString()));
      }

      final lb = extra['lookbookId'];
      if (lb != null) _selectedLookbookId = lb.toString();

      final purl = extra['imageURL'] ?? extra['resultImageUrl'];
      if (purl != null) _previewImageUrl = purl.toString();
    }

    _selectedDate = _dateOnly(_selectedDate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCalendarPreviewIfEdit();
    });
  }

  Future<void> _onPickPlace() async {
    final KakaoPlace? picked = await context.push<KakaoPlace>('/placeSearch');
    if (picked == null) return;

    setState(() {
      _placeName = picked.name;
      _lat = picked.lat;
      _lon = picked.lon;
    });
  }

  Future<void> _onAddScheduleText() async {
    final controller = TextEditingController(text: _scheduleText ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('일정 입력'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '예) 친구 만나기 / 데이트 / 회식 등',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    setState(() => _scheduleText = result);
  }

  Future<void> _onPickWardrobeAndCombine() async {
    if (_isSaving) return;

    final wardrobeResult =
    await context.push<Map<String, dynamic>>('/scheduleWardrobe');
    if (wardrobeResult == null) return;

    final List<String> clothesIds =
    (wardrobeResult['clothesIds'] as List<dynamic>? ?? []).cast<String>();

    final Map<String, dynamic> imageUrlsRaw =
    (wardrobeResult['imageUrls'] as Map<String, dynamic>? ?? {});
    final Map<String, String> imageUrls =
    imageUrlsRaw.map((k, v) => MapEntry(k, v.toString()));

    if (clothesIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택된 옷이 없습니다.')),
      );
      return;
    }

    final combineResult = await context.push<Map<String, dynamic>>(
      '/scheduleCombine',
      extra: {
        'clothesIds': clothesIds,
        'imageUrls': imageUrls,
        'selectedDate': _selectedDate,
      },
    );

    if (combineResult == null) return;
    if (combineResult['action'] != 'registerToSchedule') return;

    final List<String> finalClothesIds =
    (combineResult['clothesIds'] as List<dynamic>? ?? []).cast<String>();
    final Uint8List? canvasPngBytes =
    combineResult['canvasPngBytes'] as Uint8List?;

    if (finalClothesIds.isEmpty ||
        canvasPngBytes == null ||
        canvasPngBytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('조합 결과가 없습니다.')),
      );
      return;
    }

    setState(() {
      // ✅ wardrobe/combine 수정 시: 룩북 선택값 해제
      _selectedLookbookId = null;
      _previewImageUrl = null;

      _clothesIds = finalClothesIds;
      _canvasPngBytes = canvasPngBytes;
      _imageUrls = imageUrls;
    });
  }

  Future<void> _onPickLookbook() async {
    if (_isSaving) return;

    final result = await context.push<Map<String, dynamic>>('/scheduleLookbook');
    if (result == null) return;
    if (result['action'] != 'selectLookbook') return;

    final lookbookId = (result['lookbookId'] ?? '').toString().trim();
    final imageUrl =
    (result['imageURL'] ?? result['resultImageUrl'] ?? '').toString().trim();

    if (lookbookId.isEmpty || imageUrl.isEmpty) return;

    setState(() {
      // ✅ 룩북 교체 시: combine 결과 해제
      _selectedLookbookId = lookbookId;
      _previewImageUrl = imageUrl;

      _canvasPngBytes = null;
      _clothesIds = [];
      _imageUrls = {};
    });
  }

  Future<void> _onSubmit() async {
    if (_isSaving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    try {
      setState(() => _isSaving = true);

      final destinationName = _placeName ?? '없음';
      final planText = _scheduleText ?? '';

      if (_mode == 'create') {
        final bool hasLookbookPick =
            (_selectedLookbookId ?? '').isNotEmpty &&
                (_previewImageUrl ?? '').trim().isNotEmpty;

        final bool hasCombinePick = _canvasPngBytes != null &&
            _canvasPngBytes!.isNotEmpty &&
            _clothesIds.isNotEmpty;

        if (!hasLookbookPick && !hasCombinePick) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('코디 조합 또는 룩북 선택이 필요합니다.')),
          );
          return;
        }

        if (hasLookbookPick) {
          await _firestoreService.createScheduleAndCalendar(
            userId: user.uid,
            date: _selectedDate,
            weather: 'unknown',
            destinationName: destinationName,
            lat: _lat,
            lon: _lon,
            planText: planText,
            lookbookId: _selectedLookbookId!,
            imageURL: _previewImageUrl!.trim(),
          );
        } else {
          final resultImageUrl = await _firestoreService.uploadLookbookCanvasPng(
            userId: user.uid,
            pngBytes: _canvasPngBytes!,
          );

          final lookbookId = await _firestoreService.createLookbookWithFlag(
            userId: user.uid,
            alias: (planText.trim().isNotEmpty) ? planText.trim() : '일회성 코디',
            resultImageUrl: resultImageUrl,
            clothesIds: _clothesIds,
            inLookbook: true,
            publishToCommunity: false,
          );

          await _firestoreService.createScheduleAndCalendar(
            userId: user.uid,
            date: _selectedDate,
            weather: 'unknown',
            destinationName: destinationName,
            lat: _lat,
            lon: _lon,
            planText: planText,
            lookbookId: lookbookId,
            imageURL: resultImageUrl,
          );
        }
      } else {
        if ((_scheduleId ?? '').isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('수정에 필요한 scheduleId가 없습니다.')),
          );
          return;
        }

        final bool hasLookbookPick =
            (_selectedLookbookId ?? '').isNotEmpty &&
                (_previewImageUrl ?? '').trim().isNotEmpty;
        final bool hasCombinePick = _canvasPngBytes != null &&
            _canvasPngBytes!.isNotEmpty &&
            _clothesIds.isNotEmpty;

        if (hasLookbookPick && !hasCombinePick) {
          await _firestoreService.updateScheduleAndCalendar(
            userId: user.uid,
            date: _selectedDate,
            scheduleId: _scheduleId!,
            destinationName: destinationName,
            lat: _lat,
            lon: _lon,
            planText: planText,
            imageURL: _previewImageUrl!.trim(),
            lookbookId: _selectedLookbookId!,
          );
        } else if (hasCombinePick) {
          final resultImageUrl = await _firestoreService.uploadLookbookCanvasPng(
            userId: user.uid,
            pngBytes: _canvasPngBytes!,
          );

          final newLookbookId = await _firestoreService.createLookbookWithFlag(
            userId: user.uid,
            alias: (planText.trim().isNotEmpty) ? planText.trim() : '일정 코디(수정)',
            resultImageUrl: resultImageUrl,
            clothesIds: _clothesIds,
            inLookbook: true,
            publishToCommunity: false,
          );

          await _firestoreService.updateScheduleAndCalendar(
            userId: user.uid,
            date: _selectedDate,
            scheduleId: _scheduleId!,
            destinationName: destinationName,
            lat: _lat,
            lon: _lon,
            planText: planText,
            imageURL: resultImageUrl,
            lookbookId: newLookbookId,
          );
        } else {
          await _firestoreService.updateScheduleAndCalendar(
            userId: user.uid,
            date: _selectedDate,
            scheduleId: _scheduleId!,
            destinationName: destinationName,
            lat: _lat,
            lon: _lon,
            planText: planText,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _mode == 'create' ? '일정에 등록되었습니다.' : '일정이 수정되었습니다.'),
        ),
      );

      context.go('/userScheduleCalendar');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _infoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 4),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _pillButton({required String text, required VoidCallback onTap}) {
    const lime = Color(0xFFCAD83B);
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: _isSaving ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: lime,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.black),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }

  Widget _squareActionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    const cardPurple = Color(0xFFC9B7FF);

    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: cardPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.black),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _isSaving ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: Colors.black),
                const SizedBox(height: 12),
                Text(
                  _isSaving ? '저장 중...' : text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _labelValueRow({
    required String label,
    required String value,
    required VoidCallback onAdd,
    required String actionText,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        _pillButton(text: actionText, onTap: onAdd),
      ],
    );
  }

  Widget _previewBox() {
    final bytes = _canvasPngBytes;
    final url = (_previewImageUrl ?? '').trim();

    Widget child;
    if (bytes != null && bytes.isNotEmpty) {
      child = Image.memory(bytes, fit: BoxFit.cover);
    } else if (url.isNotEmpty) {
      child = Image.network(url, fit: BoxFit.cover);
    } else {
      child = const Center(
        child: Text(
          '프리뷰 없음',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      );
    }

    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black, width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }

  // ✅ edit 전용: “옷장으로 수정 / 룩북으로 교체” 2개 버튼
  Widget _editModifyButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: _isSaving ? null : _onPickWardrobeAndCombine,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '옷장으로 코디 수정',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: _isSaving ? null : _onPickLookbook,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '룩북으로 교체',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w800);

    final bool isCreate = _mode == 'create';
    final bool isEdit = _mode == 'edit';

    final bool hasBytes = _canvasPngBytes != null && _canvasPngBytes!.isNotEmpty;
    final bool hasUrl = (_previewImageUrl ?? '').trim().isNotEmpty;
    final bool hasAnyPreview = hasBytes || hasUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/userScheduleCalendar'),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _mode == 'edit' ? '일정 수정하기' : '일정 추가하기',
                        style: titleStyle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 18),

              _infoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtDate(_selectedDate),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    WeatherWidget(
                      date: _selectedDate,
                      lat: _lat,
                      lon: _lon,
                      apiKey: _openWeatherApiKey,
                    ),
                    const SizedBox(height: 14),
                    _labelValueRow(
                      label: '목적지',
                      value: _placeName == null ? '없음' : _placeName!,
                      onAdd: _onPickPlace,
                      actionText: isEdit ? '수정' : '추가',
                    ),
                    const SizedBox(height: 12),
                    _labelValueRow(
                      label: '일정',
                      value: (_scheduleText == null || _scheduleText!.isEmpty)
                          ? '없음'
                          : _scheduleText!,
                      onAdd: _onAddScheduleText,
                      actionText: isEdit ? '수정' : '추가',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ✅ create: 선택 전
              if (isCreate && !hasAnyPreview)
                Row(
                  children: [
                    Expanded(
                      child: _squareActionButton(
                        icon: Icons.checkroom_outlined,
                        text: '나의 옷\n가져오기',
                        onTap: _onPickWardrobeAndCombine,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _squareActionButton(
                        icon: Icons.menu_book_outlined,
                        text: '나의 룩북\n가져오기',
                        onTap: _onPickLookbook,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    if (isEdit || hasAnyPreview) _previewBox(),
                    if (isEdit || hasAnyPreview) const SizedBox(height: 10),

                    // ✅ edit: 두 가지 모두 수정 가능
                    if (isEdit)
                      _editModifyButtons()
                    else if (isCreate)
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : (hasBytes
                              ? _onPickWardrobeAndCombine
                              : _onPickLookbook),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            hasBytes ? '코디 다시 조합하기' : '룩북 다시 선택하기',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                  ],
                ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCAD83B),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.black),
                    ),
                  ),
                  child: Text(
                    _isSaving
                        ? '저장 중...'
                        : (_mode == 'edit' ? '일정 수정 완료하기' : '일정 등록 완료하기'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
