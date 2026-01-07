# 🥼 MODE
> My Outfits Daily Everyday
<p align="center">
  <img src="readmeIMG/applogo.png" alt="App Logo" width="300"/>
</p>



## 📋 프로젝트 개요
일상의 코디를 기록하고 관리하는 모바일 옷장 서비스입니다. 사용자는 보유한 옷을 체계적으로 관리하고, 외출 목적에 맞는 코디를 계획하며, 커뮤니티를 통해 스타일 조언을 받을 수 있습니다.

## 📌 프로젝트 소개
외출 다이어리(Outfit Diary)는 일상의 코디를 기록하고 관리할 수 있는 모바일 디지털 옷장 서비스입니다.
사용자는 자신이 보유한 옷을 체계적으로 관리하고, 외출 목적에 맞는 코디를 계획하며,
외출 후에는 일기처럼 기록하고 커뮤니티를 통해 스타일에 대한 조언과 공감을 나눌 수 있습니다.
단순한 코디 전시 앱이 아닌,
옷장 관리 → 코디 구성 → 외출 기록 → 커뮤니티 공유까지 이어지는
하나의 완성된 패션 라이프 사이클을 제공합니다.

<br>

### 😀 팀원 구성
| 이름 | GitHub |
|------|--------|
| 김예슬 | https://github.com/yeseul1008 |
| 김동준 | https://github.com/jun-000224 |
| 김반석 | https://github.com/KIMBANSEOK92 |
| 아린 | https://github.com/aline-rousselinsiv |

<br>

### ⏳ 개발 기간
🗓️ **총 개발 기간:** 2025년 12월 23일 ~ 01월 08일 (약 3주간)
|기간|주요 진행 내용|
|------|----------------|
|2025년 12월 23일 ~ 2025년 12월 26일 | 문서화(회의록) 및 피그마 설계 |
|2025년 12월 29일 ~ 2025년 12월 30일| Flutter(설계 보완 및 파이어베이스 db설계) 역할분담 작업시작 |
|2025년 12월 31일 ~ 2026년 01월 08일 | 역할페이지 작업 및 테스트|

<br>

## 📁 Project Structure

```text
lib/
├── main.dart                     - 앱 진입점
│
├── routes/                       - 라우팅 관리
│   └── main_route.dart
│
├── firebase/                     - Firebase 설정 및 공통 서비스
│   ├── firebase_options.dart
│   └── firebase_service.dart
│
├── pages/                        - 주요 화면(Page) 단위
│   │
│   ├── auth/                     - 인증 관련 화면
│   │   ├── user_login.dart
│   │   ├── user_google_login.dart
│   │   ├── user_join.dart
│   │   └── find_acc.dart
│   │
│   ├── wardrobe/                 - 디지털 옷장 & 룩북
│   │   ├── user_wardrobe_list.dart
│   │   ├── user_wardrobe_category.dart
│   │   ├── user_wardrobe_add.dart
│   │   ├── user_lookbook.dart
│   │   ├── user_lookbook_add.dart
│   │   ├── user_scrap.dart
│   │   ├── user_scrap_view.dart
│   │   └── outfit_maker.dart
│   │
│   ├── profile/                  - 마이페이지 & 다이어리
│   │   ├── user_diary_cards.dart
│   │   ├── user_diary_map.dart
│   │   ├── user_diary_calendar.dart
│   │   ├── user_profile_edit.dart
│   │   ├── user_public_wardrobe.dart
│   │   └── user_public_lookbook.dart
│   │
│   ├── community/                - 커뮤니티 & QnA
│   │   ├── main_feed.dart
│   │   ├── question_feed.dart
│   │   ├── question_add.dart
│   │   ├── question_comment.dart
│   │   └── follow_list.dart
│   │
│   └── admin/                    - 관리자 페이지
│       └── admin_page.dart
│
└── widgets/                      - 재사용 UI 컴포넌트
    │
    ├── common/                   - 공통 위젯
    │   ├── main_btn.dart
    │   ├── sub_button.dart
    │   ├── drawer_menu.dart
    │   ├── bottom_nav_bar.dart
    │   ├── text_input.dart
    │   ├── like_btn.dart
    │   ├── snack_bar.dart
    │   └── share_plus.dart
    │
    ├── wardrobe/                 - 옷장 관련 UI 컴포넌트
    │   └── clothes_card.dart
    │
    └── diary/                    - 다이어리 관련 UI 컴포넌트
        ├── weather_chip.dart
        └── purpose_chip.dart
```


<br>

## 🖥️ **기술 스택**
|구분|기술|
|------|----------------|
|**Backend**|![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)|
|**Frontend**|![Android Studio](https://img.shields.io/badge/android%20studio-346ac1?style=for-the-badge&logo=android%20studio&logoColor=white) |
|**Database**|![Firebase](https://img.shields.io/badge/firebase-a08021?style=for-the-badge&logo=firebase&logoColor=ffcd34)|
|**Tools**|![Figma](https://img.shields.io/badge/figma-%23F24E1E.svg?style=for-the-badge&logo=figma&logoColor=white) ![GitHub](https://img.shields.io/badge/github-%23121011.svg?style=for-the-badge&logo=github&logoColor=white) ![Google Drive](https://img.shields.io/badge/Google%20Drive-4285F4?style=for-the-badge&logo=googledrive&logoColor=white) ![KakaoTalk](https://img.shields.io/badge/kakaotalk-ffcd00.svg?style=for-the-badge&logo=kakaotalk&logoColor=000000) ![Instagram](https://img.shields.io/badge/Instagram-%23E4405F.svg?style=for-the-badge&logo=Instagram&logoColor=white) ![Facebook](https://img.shields.io/badge/Facebook-%231877F2.svg?style=for-the-badge&logo=Facebook&logoColor=white) ![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)|
|**Collaboration**|![Google Gemini](https://img.shields.io/badge/google%20gemini-8E75B2?style=for-the-badge&logo=google%20gemini&logoColor=white) ![ChatGPT](https://img.shields.io/badge/chatGPT-74aa9c?style=for-the-badge&logo=openai&logoColor=white) |

<br>

## 📂 프로젝트 자료 모음
| 분류 | 링크 |
|------|------|
| 📝 회의록 | 📅 [1회차 회의록](https://docs.google.com/document/d/1xQXNfiVdnWR8__4PAtTqPMBrZyrpG0Kw6K73RPqs-4k/edit?tab=t.7y908es3yuq) <br> 📅 [2회차 회의록](https://docs.google.com/document/d/1ba9YWrBuRw63KOHbEYD_QMjfeJkOcVIqZQJ92tcYr6s/edit?tab=t.0) <br> 📅 [3회차 회의록](https://docs.google.com/document/d/1vq4wwx3afmFLc00ERxrCCkcfRcPvciKWhzbkY7umeyQ/edit?tab=t.0) <br> 📅 [4회차 회의록](https://docs.google.com/document/d/1xJ1OdjF5AHMCv0iy4lhsbJz4yekFyEjKbr3CK_puW6Y/edit?tab=t.0) |
| 🏗 설계 자료 | 🎨 [Figma 설계 보기](https://www.figma.com/design/xIKwyhMPDhbnGMi1fLVoVU/%ED%94%8C%EB%9F%AC%ED%84%B0-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8-%ED%99%94%EB%A9%B4%EA%B5%AC%EC%84%B1?node-id=0-1&p=f&t=7U7g0LV7wZ1mGv9K-0) |
| 📚 공통 문서 | 📁 [공통 문서 폴더 보기](https://drive.google.com/drive/u/0/folders/16c1vWnDJNyonibTgSbnFPx56UtfGC8ld) |

<br>

## 🖍 차별점
- 외출 기록 중심: 단순 코디 전시가 아닌 일상 기록 및 히스토리 관리
- 커뮤니티 서포트: 사용자 옷장 기반 맞춤형 코디 추천
- 한국 시장 특화: 소개팅, 결혼식 등 한국 문화 반영
- 통합 경험: 옷장 관리 → 코디 계획 → 외출 기록 → 커뮤니티 공유의 원스톱 서비스

<br>

## 📱 화면 구성
- 로그인/회원가입
- 옷장 (목록/추가/수정/삭제)
- 룩북 생성 도구
- 캘린더
- 일기 작성/조회
- 커뮤니티 피드
- QnA 게시판
- 마이페이지

<br>

# 📽 주요 기능
## 1. 로그인/회원가입
### 이메일/아이디/전화번호 회원가입
- 소셜 로그인 (Google)
- 아이디찾기/비밀번호찾기
- 프로필 이미지 및 성별 선택

| Splash | 회원가입 | 로그인 |
|--------|----------|--------|
| ![Splash](readmeIMG/스플래시.jpg) | ![회원가입](readmeIMG/회원가입.jpg) | ![로그인](readmeIMG/로그인.jpg) |

<br>

## 2. Closet (옷장/룩북/스크랩)
### 2-1. 옷장
- 사용자 전용 커스텀 카테고리 추가 가능
- 옷 등록시 누끼 api (remove.bg 사용)
- 옷 선택후 ai 착용사진 생성

| 옷장 | 카테고리 | 옷 등록 | ai착용샷 |
|------|------|------|------|
|![옷장](readmeIMG/closet.jpg)|![회원가입](readmeIMG/카테고리.jpg)|![회원가입](readmeIMG/옷추가.jpg)|![회원가입](readmeIMG/카테고리.jpg)|우터, 상의, 하의, 원피스, 신발, 악세사리
- 사용자 커스텀 카테고리 추가 가능

<br>

## 3. 룩북(Lookbook) 생성
- 옷장의 옷 2개 이상 조합
- 편집 툴로 배치 및 이미지 생성
- 룩북 별칭 설정
- 커뮤니티 피드 게시 여부 선택

<br>

## 4. 캘린더 & 외출 일기
### 캘린더
- 특정 날짜에 룩북 매칭
- 일기 작성
- 필수: 룩북 선택, 날짜, 위치, 날씨, 코멘트
- 지도 API 연동으로 위치 기록
- 날씨 API 연동

<br>

## 5. 커뮤니티
- 피드
- 룩북 게시 및 공유
- 좋아요 & 스크랩 기능
- 다른 사용자의 룩북 스크랩 모아보기
### QnA 게시판
- 사진 여러 장 + 텍스트 업로드
- 댓글로 코디 조언 받기
- 다른 사용자의 옷장 열람 후 맞춤 추천

<br>

## 6. 소셜 기능
- 팔로우/언팔로우
- 팔로잉 목록 확인
- 사용자 프로필 조회

<br>

## 7. 마이페이지
- 개인정보 수정
- 작성한 게시글/댓글 관리
- 좋아요 & 스크랩 목록
- 회원 탈퇴

<br>






