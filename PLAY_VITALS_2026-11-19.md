# Google Play Console — Android Vitals: जाँच और सुधार

**तारीख:** 19 नवंबर 2026
**ऐप:** Gora Taxi Partner (`com.taxi.call_taxi_partner`)
**Play पर अभी लाइव:** Release **47** (1.3.0), 29 अक्टूबर को बनी
**तैयार बिल्ड:** 1.3.0+48 — अभी release नहीं की गई

---

## 1. Crash क्यों बढ़ा — और fix पहले से तैयार पड़ा है

Crash rate पिछले 28 दिन में **+2.04% बढ़ा** (लगभग 0.25% → 2.29%)। यह पुराना bug नहीं,
एक **recent release का regression** है। तारीखें बिल्कुल मेल खाती हैं:

| तारीख | क्या हुआ |
|---|---|
| **22 अक्टूबर, 16:49** | "loud alerts" feature जुड़ा — booking पर overlay popup + ring (`26ac2e4`) |
| **22 अक्टूबर, 17:54** | वही feature **v44 में release** हुआ (`05877ec`) |
| **22 अक्टूबर से** | **Play का crash graph यहीं से ऊपर जाना शुरू होता है** |
| 29 अक्टूबर | **Release 47 बनी — यही अभी लाइव है** |
| **30 अक्टूबर** | इसी crash की **असली वजह पकड़ी और ठीक की गई** (`7b43a82`) |

### असली वजह

हर FCM alert अपना अलग background isolate खोलता है, और हर isolate एक ही native overlay
window चलाने की कोशिश करता है। कई alert एक साथ आने पर वे आपस में **deadlock** हो जाते हैं।

Emulator पर नापा गया था: **एक साथ 4 alert → 2 isolate कभी वापस नहीं लौटे**। जो background
isolate कभी खत्म नहीं होता, Android उसे **मार देता है** — user को यही दिखता है:
**"App keeps stopping"**। वही 4 alert एक-एक करके भेजने पर चारों ~6 सेकंड में पूरे हुए,
यानी दिक्कत **overlap** से है, alert की संख्या से नहीं।

### दिक्कत यह है कि वह fix users तक पहुँचा ही नहीं

Fix **30 अक्टूबर** को repo में आ गया था, पर **release 47 एक दिन पहले, 29 अक्टूबर को बन
चुकी थी**। उसके बाद कोई release नहीं गई। यानी **3 हफ़्ते से users उसी टूटे build पर हैं**,
जबकि fix तैयार रखा है।

> **सबसे पहला काम नया code लिखना नहीं — release 48 निकालना है।**

---

## 2. Play Console असल में क्या कहता है

मैसेज में 6 points थे। Play खुद इन्हें दो अलग श्रेणियों में रखता है, और यह अंतर ज़रूरी है:

**"2 issues need attention"** — असली समस्या, Play पर ऐप की visibility घटाती है:
- Crash rate **2.27%** (threshold 1.09%) — "Bad behavior"
- DEX obfuscation **2%** — deadline **Feb 2027**

**"3 actions recommended"** — सुझाव (User experience):
- Edge-to-edge सभी users पर ठीक नहीं दिख रहा
- Edge-to-edge के लिए deprecated API
- Large screen के लिए orientation restriction हटाएँ

### ANR असल में समस्या है ही नहीं

मैसेज में ANR को priority #2 बताया गया है। Play का अपना डेटा उल्टा कहता है:

- ANR rate **0.17%**
- "Bad behavior" का निशान **नहीं**
- **peers के median से 0.16% बेहतर** (−0.16%)

इस मामले में ऐप अपने जैसे दूसरे ऐप्स से **अच्छा** चल रहा है। ANR पर अलग मेहनत की ज़रूरत
नहीं — और जितना बढ़ा (+0.14%), उसकी वजह भी वही overlay deadlock है, जिसका fix release 48
में पहले से है।

---

## 3. हर point का status

| # | मैसेज का point | असली वजह | अब क्या है |
|---|---|---|---|
| 1 | Crash rate 2.27% | Overlay alert deadlock (v44, 22 अक्टूबर) | Fix तैयार, release होना बाकी + startup hardening + Crashlytics |
| 2 | ANR 0.17% | **समस्या नहीं** — peers से बेहतर | वही deadlock fix इसे भी कवर करता है |
| 3 | Obfuscation 2% | `isMinifyEnabled = false` — **R8 पूरी तरह बंद था** | R8 चालू + keep rules → **65.7%** (नापा गया) |
| 4 | Edge-to-edge | `statusBarColor` — API 35 से deprecated, API 36 पर बेअसर | हटाया; साथ में एक असली layout bug भी ठीक |
| 5 | Deprecated APIs | ऊपर वाला ही point | वही fix |
| 6 | Large screen | `setPreferredOrientations(portrait)` हर device पर | अब portrait सिर्फ़ फ़ोन पर; tablet/foldable घूमते हैं |

---

## 4. विस्तार से

### 4.1 Obfuscation: 2% → 65.7%

वजह सीधी थी — `build.gradle.kts` में `isMinifyEnabled = false`, यानी **R8 कभी चला ही नहीं**।
हर class अपने असली नाम से DEX में थी। जो 2% दिख रहा था, वह पहले से obfuscated library code था।

R8 चालू किया, और उन plugins के लिए keep rules लिखे जो runtime पर classes को **नाम से**
ढूँढते हैं (R8 उन्हें देख नहीं पाता):

- **Razorpay** — payment का result method के **नाम** से वापस आता है। बिना rule के payment
  sheet खुलती और result कभी नहीं आता — पैसा कटता, ऐप को पता न चलता।
- **Gson** — notifications और Play services इसी से models पढ़ते हैं।
- **flutter_overlay_window**, **FCM background handler** — booking alert का पूरा रास्ता।

नापे गए नतीजे:
- Obfuscation **65.7%** (5,906 में से 3,881 classes rename) — Play की 25% limit से काफ़ी ऊपर
- APK size **90.9 MB → 86.5 MB**
- `mapping.txt` AAB में जाता है, इसलिए Play Console पर crash traces **पढ़ने लायक रहेंगे**

**Resource shrinking जानबूझकर बंद रखा** — Play की शिकायत DEX की है, resources की नहीं।
उसे चालू करने पर ringtone files (`gora_ring*`) और notification icon हट सकते थे, क्योंकि वे
runtime पर **नाम से** ढूँढे जाते हैं।

### 4.2 Edge-to-edge और deprecated API

ऐप `targetSdk 36` पर है, जहाँ Android हर ऐप को status/navigation bar के **पीछे** draw
कराता है और इससे बाहर निकलने का रास्ता नहीं देता।

कोड में `statusBarColor: Colors.transparent` था। यह अंदर से `Window.setStatusBarColor()`
बनता है — **API 35 से deprecated, API 36 पर बिल्कुल बेअसर**। Play इसी को
"deprecated APIs for edge-to-edge" बता रहा था। वह line हटा दी।

**साथ में एक असली bug मिला:** location picker (pickup/drop चुनने वाली screen) में
"Confirm Location" बटन `bottom: 0` पर टँगा था, बिना inset के। यानी Android 15/16 वाले
users पर वह बटन **अभी भी navigation bar के नीचे दबा है** — three-button navigation पर तो
आधा ढका रहता है। ठीक कर दिया।

### 4.3 Large screen

`setPreferredOrientations([portraitUp])` हर device पर चल रहा था — Play का check ठीक यही
पकड़ता है। अब यह सिर्फ़ फ़ोन (600dp से छोटी screen) पर लगता है; tablet और खुले foldable घूम
सकते हैं, और foldable खुलते ही दोबारा तय होता है।

वैसे भी Android 16 में targetSdk 36 वाले ऐप्स पर बड़ी screens पर यह lock **पहले से बेअसर**
है — tablet पहले से घूम रहे थे, ऐप बस उनसे लड़ रहा था।

> ध्यान दें: tablet पर layout घूमता तो है, पर design फ़ोन का ही है इसलिए बड़ा-बड़ा दिखता है।
> Play की माँग सिर्फ़ "restriction हटाओ" की है। Tablet का अलग design एक अलग काम है।

### 4.4 Crash की वजह दिखे, इसके लिए

अब तक ऐप में **कोई crash reporting नहीं थी** — न Crashlytics, न Sentry। इसलिए "crash क्यों
हुआ" का जवाब देने का रास्ता ही नहीं था। Play Console का अपना data Flutter ऐप के लिए लगभग
बेकार है, क्योंकि Dart का असली stack `libapp.so` के अंदर होता है।

इसलिए जोड़ा गया:

**(क) Firebase Crashlytics** — अब हर crash के साथ Dart का पूरा stack आएगा, यानी दिखेगा कि
**कौन सा function** टूटा। Firebase पहले से ऐप में है, इसलिए कोई नया vendor नहीं जुड़ा।

**(ख) दो global error handlers** — इनमें से एक सीधे crash rate घटाता है: जिस async error को
कोई नहीं पकड़ता, वह अभी **पूरी app बंद कर देता है**। अब वह report होकर ऐप चलता रहता है।
Driver के trip के बीच एक API response गिरने पर ऐप बंद नहीं होना चाहिए।

**(ग) Startup hardening** — `main()` में `runApp()` से *पहले* चार काम बिना सुरक्षा के हो रहे
थे। कोई भी fail होता तो ऐप **पहली frame से पहले ही मर जाता**। और वजह बनी रहती, यानी वही
user **हर बार** crash होता — इसी तरह थोड़े से खराब devices पूरा crash rate ऊपर खींच लेते हैं।

### 4.5 पहली बार ऐप खोलने पर खाली screen

Testing में यह भी सामने आया: नया install खोलते ही **खाली screen पर notification permission
का dialog** आता है। वजह — notification setup `runApp()` से पहले await हो रहा था, और उसके
अंदर permission dialog user के जवाब का इंतज़ार करता है। user जितनी देर सोचे, ऐप उतनी देर
**खाली पड़ा रहता है**।

Emulator पर पुष्टि हुई: dialog बंद करते ही UI तुरंत आया, उससे पहले नहीं। अब notification
setup **पहली frame के बाद** चलता है, इसलिए ऐप तुरंत दिखता है।

---

## 5. क्या test किया गया

पूरी testing **R8 वाली release build पर** की गई है (debug build पर नहीं) — क्योंकि असली
सवाल यही था कि obfuscation से कुछ टूटता तो नहीं। Build को local backend पर point करके
emulator पर चलाया गया, **production को छुआ नहीं गया**।

### Build और obfuscation

| जाँच | नतीजा |
|---|---|
| Release build बनना (R8 के साथ) | ✅ AAB 65.6 MB, APK 86.5 MB |
| Obfuscation % | ✅ **65.7%** (Play की limit 25%) |
| ज़रूरी classes के नाम बचे | ✅ Razorpay, MainActivity, OverlayService, FCM, notifications |
| Plugin entry points | ✅ in_app_update, geolocator, maps, razorpay, audioplayers |
| In-app update R8 से टूटा? | ✅ नहीं — R8 ने सिर्फ़ **बेकार पड़े overloads** हटाए |
| `flutter analyze` | ✅ कोई error नहीं |

### ऐप असल में चलाकर (end-to-end, R8 build पर)

| जाँच | नतीजा |
|---|---|
| Driver login (OTP) | ✅ चला — token सेव हुआ, home खुला |
| Home feed, banners, tiles | ✅ पूरा render, कोई crash नहीं |
| Google Places autocomplete | ✅ pickup/drop दोनों पर suggestions आईं |
| **Booking post** | ✅ **DB में पहुँचा** — `one_way / sedan / inclusive / active`, time भी मेल खाता है |
| In-app update (Play Core) | ✅ R8 के बाद भी चला (`AppUpdateService: requestUpdateInfo`) |
| Crashlytics | ✅ चालू — `Firebase Crashlytics 19.4.4`, `collect_reports: true`, **`collect_anrs: true`** |
| FCM background service | ✅ `FlutterFirebaseMessagingBackgroundService started!` — alert वाला रास्ता सही |
| पूरे दौरान logcat | ✅ एक भी FATAL / crash नहीं |

### पहली बार खोलने वाला fix (पहले vs बाद)

| | पहले | अब |
|---|---|---|
| नया install खोलने पर | permission dialog **खाली grey screen** पर | पूरा role-select page **पीछे दिखता है** |

दोनों के screenshot लिए गए हैं।

### Orientation

| जाँच | नतीजा |
|---|---|
| फ़ोन (sw411dp) — rotation ज़बरदस्ती | ✅ portrait ही रहा — **कोई बदलाव नहीं** |
| Tablet (sw1067dp) | ✅ landscape में घूमा, crash नहीं, `SCREEN_ORIENTATION_FULL_USER` |

---

## 6. आगे क्या चाहिए

### (क) Play Console से crash की असली details — सबसे ज़रूरी

ऊपर बताई वजह **तारीख़ों का पक्का मेल + पहले से नापा हुआ deadlock** है। लेकिन यह कहना कि
पूरा 2.27% इसी से है, बिना असली data के सही नहीं होगा।

कृपया भेजें:
**Android vitals → Crashes and ANRs → Crashes → Last 28 days → sessions से sort** — और ऊपर
के **3 crashes** के title + stack trace।

उससे पक्का पता चलेगा कि बाकी कितना हिस्सा किसी और वजह से है।

### (ख) Data safety declaration update करनी होगी

Crashlytics जुड़ने से ऐप अब **crash logs + diagnostics** भेजेगा। Release से **पहले**
Play Console → App content → Data safety में यह declare करना ज़रूरी है, वरना policy
violation बन सकता है।

### (ग) Release किस क्रम में निकालें

दोनों बदलाव एक साथ भेजने की सलाह **नहीं** है — crash fix और R8 एक ही release में गए और
crash rate नहीं गिरा, तो पता नहीं चलेगा कि किस वजह से।

| Release | क्या जाए | क्यों |
|---|---|---|
| **48 (तुरंत)** | Overlay deadlock fix + Crashlytics + startup hardening + edge-to-edge + large screen | आग पहले बुझे, और आगे की crashes दिखने लगें |
| **49 (3–5 दिन बाद)** | R8 / obfuscation | 48 का असर साफ़ दिखने के बाद। Deadline Feb 2027 है, जल्दी नहीं |

एक ही release में सब भेजना हो तो वह भी ठीक है — बस Play Console पर 3–4 दिन नज़र रखनी होगी,
और crash बढ़े तो सबसे पहले R8 को शक की नज़र से देखना होगा।

### (घ) जो testing बाकी है

मैसेज में 8 flows गिनाए गए थे। इनमें से **Driver Login** और **Booking Post** पूरे करके
ऊपर दिखाए गए हैं। बाकी अभी नहीं हुए, और वजह साफ़ है:

| Flow | स्थिति |
|---|---|
| Driver Login | ✅ हो गया |
| Booking Post | ✅ हो गया |
| Customer Login | बाकी — अलग customer account चाहिए |
| Booking Accept | बाकी — **दूसरा** account चाहिए (अपनी ही booking accept नहीं होती) |
| Wallet Deduction | बाकी — पहले से balance वाला test account चाहिए |
| Commission Payment | बाकी — Razorpay test keys चाहिए |
| Refund | बाकी — admin action चाहिए |
| Booking Completion | बाकी — पूरा assigned trip चाहिए |

एक बात ध्यान देने लायक: ये सारे flows **Dart code** हैं, और **R8 Dart को छूता ही नहीं** —
वह सिर्फ़ Android/Java वाले हिस्से (plugins) पर चलता है। R8 से जो भी टूट सकता था, वे
plugins ऊपर एक-एक करके जाँचे जा चुके हैं। फिर भी पूरी regression testing करानी हो तो
balance और pending commission वाले test accounts दे दें, local पर करके दिखा देंगे।

---

## 7. कौन सी files बदलीं

| File | क्या |
|---|---|
| `mobile/android/app/build.gradle.kts` | R8 चालू, proguard rules जोड़े |
| `mobile/android/app/proguard-rules.pro` | **नई** — keep rules |
| `mobile/android/settings.gradle.kts` | Crashlytics Gradle plugin |
| `mobile/pubspec.yaml` | `firebase_crashlytics: ^4.3.10` |
| `mobile/lib/core/utils/crash_reporter.dart` | **नई** — crash reporting + global handlers |
| `mobile/lib/main.dart` | startup hardening, orientation policy, edge-to-edge, push ordering |
| `mobile/lib/.../location_picker_page.dart` | bottom inset fix |

**अभी कुछ भी commit या release नहीं किया गया है।**
