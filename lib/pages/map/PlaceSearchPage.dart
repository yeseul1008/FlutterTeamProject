import 'package:flutter/material.dart';
import '../../service/kakao/kakao_service.dart';
import '../../service/kakao/kakao_models.dart';

class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({super.key});

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final KakaoService _kakaoService = KakaoService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;
  String _error = '';
  List<KakaoPlace> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _error = '검색어를 입력해주세요.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final data = await _kakaoService.searchKeyword(query: q, size: 10, page: 1);
      setState(() {
        _results = data;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _results = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _selectPlace(KakaoPlace place) {
    // ✅ 선택한 장소를 이전 화면(Add 페이지)으로 반환
    Navigator.pop(context, place);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('목적지 검색'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: '예) 강남역, 성수동, 홍대입구',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black, width: 1.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _search,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('검색'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (_loading) const LinearProgressIndicator(),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              Expanded(
                child: _results.isEmpty
                    ? const Center(
                  child: Text(
                    '검색 결과가 없습니다.',
                    style: TextStyle(fontSize: 13),
                  ),
                )
                    : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = _results[index];
                    final sub = (p.roadAddress != null && p.roadAddress!.isNotEmpty)
                        ? p.roadAddress!
                        : (p.address ?? '');

                    return ListTile(
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: sub.isEmpty
                          ? null
                          : Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selectPlace(p),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
