import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/theme/app_theme.dart';

/// Static Service-Level-Agreement penalty list shown to drivers/partners, so they
/// know which inappropriate actions attract a penalty. Localised into every
/// language the app supports (falls back to English for any missing one).
class PenaltyPage extends StatelessWidget {
  const PenaltyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.instance.lang;
    final c = _content[lang] ?? _content['en']!;
    final rows = _buildRows(c);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(c.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
        children: [
          Text(c.intro, style: TextStyle(fontSize: 13.sp, height: 1.55, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          SizedBox(height: 18.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
            ),
            child: Row(children: [
              SizedBox(width: 34.w, child: _hCell(c.sNo)),
              Expanded(flex: 6, child: _hCell(c.actionHdr)),
              Expanded(flex: 3, child: _hCell('Penalty')),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.r)),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [for (int i = 0; i < rows.length; i++) _rowTile(rows[i], i.isEven)],
            ),
          ),
          SizedBox(height: 18.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 18.sp, color: AppColors.info),
              SizedBox(width: 8.w),
              Expanded(child: Text(c.footer, style: TextStyle(fontSize: 12.sp, height: 1.5, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _hCell(String t) => Text(t, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: AppColors.primary, fontFamily: 'Poppins'));

  Widget _rowTile(_PenaltyRow r, bool shade) {
    return Container(
      color: shade ? Colors.grey.withValues(alpha: 0.04) : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 34.w, child: Text(r.no, style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
            Expanded(flex: 6, child: Text(r.action, style: TextStyle(fontSize: 12.5.sp, height: 1.4, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
            Expanded(flex: 3, child: Text(r.penalty, style: TextStyle(fontSize: 12.5.sp, height: 1.4, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'Poppins'))),
          ]),
          for (final s in r.subs) ...[
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.only(left: 34.w),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 6, child: Text(s.action, style: TextStyle(fontSize: 12.sp, height: 1.4, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
                Expanded(flex: 3, child: Text(s.penalty, style: TextStyle(fontSize: 12.sp, height: 1.4, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  List<_PenaltyRow> _buildRows(_PC c) => [
        _PenaltyRow('1', c.r1, '', [
          _SubRow(c.subI, c.pLower),
          _SubRow(c.subII, c.pHigher12),
          _SubRow(c.subIII, c.pHigher3),
          _SubRow(c.subIV, 'Rs. 150'),
        ]),
        _PenaltyRow('2', c.r2, 'Rs. 50'),
        _PenaltyRow('3', c.r3, 'Rs. 200'),
        _PenaltyRow('4', c.r4, 'Rs. 200'),
        _PenaltyRow('5', c.r5, 'Rs. 250'),
        _PenaltyRow('6', c.r6, 'Rs. 100'),
        _PenaltyRow('7', c.r7, 'Rs. 200'),
        _PenaltyRow('8', c.r8, 'Rs. 250'),
      ];
}

class _PenaltyRow {
  final String no, action, penalty;
  final List<_SubRow> subs;
  const _PenaltyRow(this.no, this.action, this.penalty, [this.subs = const []]);
}

class _SubRow {
  final String action, penalty;
  const _SubRow(this.action, this.penalty);
}

/// One language's penalty copy. Technical terms (Cancellation, App, Driver, Rs.,
/// CNG, sedan, carrier, condition, Complete Journey) are kept in English on
/// purpose — that mixed style matches the rest of the app and how the reference
/// policy is written.
class _PC {
  final String title, intro, footer, sNo, actionHdr;
  final String r1, subI, subII, subIII, subIV;
  final String pLower, pHigher12, pHigher3;
  final String r2, r3, r4, r5, r6, r7, r8;
  const _PC({
    required this.title,
    required this.intro,
    required this.footer,
    required this.sNo,
    required this.actionHdr,
    required this.r1,
    required this.subI,
    required this.subII,
    required this.subIII,
    required this.subIV,
    required this.pLower,
    required this.pHigher12,
    required this.pHigher3,
    required this.r2,
    required this.r3,
    required this.r4,
    required this.r5,
    required this.r6,
    required this.r7,
    required this.r8,
  });
}

const Map<String, _PC> _content = {
  'en': _PC(
    title: 'Penalty',
    intro: 'Dear Partner,\n\nAs you know, good service is the key to our business success. We have come across some cases where partners provided inappropriate services. Therefore, to define penalties for various inappropriate services, Gora has updated the Service Level Agreement (SLA) with partners.\n\nPlease review the list below very carefully and take care to provide the best service to the customer, so that no penalty is applied to your account.',
    footer: "Gora takes appropriate steps on any inappropriate action. In case of any dispute, Gora's decision shall be final.",
    sNo: 'S.No.', actionHdr: 'Inappropriate Service action',
    r1: 'Cancelling after accepting a booking (Cancellation)',
    subI: 'i) Cancellation 12 hours before departure',
    subII: 'ii) Cancellation within 12 hours of departure',
    subIII: 'iii) Cancellation within 3 hours of departure',
    subIV: 'iv) Cancellation within 30 minutes of Accept',
    pLower: 'Rs. 400 or 10% of total value, whichever is lower',
    pHigher12: 'Rs. 400 or 10% of total value, whichever is higher',
    pHigher3: 'Rs. 700 or 10% of total value, whichever is higher',
    r2: "Driver did not mark 'Complete Journey' in the app, nor got it done via customer support.",
    r3: 'Sending a car different from the one chosen in the App to the customer.',
    r4: 'Sending a driver different from the one chosen in the Driver App to the customer.',
    r5: 'A sedan sent with neither proper boot space (diggi) nor a carrier. This can happen with CNG cars — if CNG is fitted in the sedan boot, there must be space for luggage.',
    r6: 'Car was not clean.',
    r7: 'Car was not in good condition.',
    r8: 'Driver misbehaved.',
  ),
  'hi': _PC(
    title: 'पेनल्टी',
    intro: 'प्रिय पार्टनर,\n\nजैसा कि आप जानते हैं, एक अच्छी सेवा हमारे व्यापार की सफलता की कुंजी है। हमारे सामने ऐसे कुछ मामले आए हैं जहाँ पार्टनर्स ने अनुपयुक्त सेवाएं प्रदान की हैं। इसलिए, विभिन्न अनुपयुक्त सेवाओं के लिए जुर्माने को परिभाषित करने के लिए, Gora ने पार्टनर्स के साथ सर्विस लेवल एग्रीमेंट (SLA) को अपडेट किया है।\n\nकृपया नीचे दी गई सूची को बहुत सावधानी से देखें और ग्राहक को सबसे अच्छी सेवा प्रदान करने का ख्याल रखें, ताकि आपके खाते में कोई Penalty न लगे।',
    footer: 'Gora अनुचित कार्रवाई पर उचित कदम उठाता है। किसी भी विवाद की स्थिति में Gora का निर्णय अंतिम होगा।',
    sNo: 'क्र.', actionHdr: 'अनुपयुक्त सेवा (Action)',
    r1: 'बुकिंग स्वीकार करने के बाद रद्द करना (Cancellation)',
    subI: 'i) प्रस्थान से 12 घंटे पहले Cancellation',
    subII: 'ii) प्रस्थान के 12 घंटे के भीतर Cancellation',
    subIII: 'iii) प्रस्थान के 3 घंटे के भीतर Cancellation',
    subIV: 'iv) स्वीकार (Accept) के 30 मिनट के भीतर Cancellation',
    pLower: 'Rs. 400 या कुल मूल्य के 10% में जो भी कम हो',
    pHigher12: 'Rs. 400 या कुल मूल्य के 10% में जो भी ज्यादा हो',
    pHigher3: 'Rs. 700 या कुल मूल्य के 10% में जो भी ज्यादा हो',
    r2: "चालक ने ऐप में 'Complete Journey' नहीं किया या इसे ग्राहक सहायता के माध्यम से नहीं करवाया।",
    r3: 'जो कार App में चुनी है उससे अलग कार ग्राहक को भेजना।',
    r4: 'जो Driver App में चुना है उससे अलग Driver ग्राहक को भेजना।',
    r5: 'एक sedan कार भेजी गई जिसमें न तो उचित बूट स्पेस (डिग्गी) और न ही carrier है। CNG कारों के साथ ऐसा हो सकता है — यदि CNG को सीडान के बूट में लगाया जाता है तो सामान के लिए जगह होनी चाहिए।',
    r6: 'कार साफ नहीं थी।',
    r7: 'कार अच्छी condition में नहीं थी।',
    r8: 'ड्राइवर ने दुर्व्यवहार किया।',
  ),
  'gu': _PC(
    title: 'પેનલ્ટી',
    intro: 'પ્રિય પાર્ટનર,\n\nજેમ તમે જાણો છો, સારી સેવા આપણા વ્યવસાયની સફળતાની ચાવી છે. અમારી સામે એવા કેટલાક કિસ્સા આવ્યા છે જ્યાં પાર્ટનર્સે અયોગ્ય સેવા આપી છે. તેથી, વિવિધ અયોગ્ય સેવાઓ માટે દંડ નક્કી કરવા, Gora એ પાર્ટનર્સ સાથે સર્વિસ લેવલ એગ્રીમેન્ટ (SLA) અપડેટ કર્યું છે.\n\nકૃપા કરીને નીચેની યાદી ખૂબ ધ્યાનથી જુઓ અને ગ્રાહકને શ્રેષ્ઠ સેવા આપવાનું ધ્યાન રાખો, જેથી તમારા ખાતામાં કોઈ Penalty ન લાગે.',
    footer: 'Gora અયોગ્ય કાર્યવાહી પર યોગ્ય પગલાં લે છે. કોઈપણ વિવાદમાં Gora નો નિર્ણય અંતિમ રહેશે.',
    sNo: 'ક્રમ', actionHdr: 'અયોગ્ય સેવા (Action)',
    r1: 'બુકિંગ સ્વીકાર્યા પછી રદ કરવું (Cancellation)',
    subI: 'i) પ્રસ્થાનના 12 કલાક પહેલાં Cancellation',
    subII: 'ii) પ્રસ્થાનના 12 કલાકની અંદર Cancellation',
    subIII: 'iii) પ્રસ્થાનના 3 કલાકની અંદર Cancellation',
    subIV: 'iv) સ્વીકાર (Accept) ના 30 મિનિટની અંદર Cancellation',
    pLower: 'Rs. 400 અથવા કુલ મૂલ્યના 10% માંથી જે ઓછું હોય',
    pHigher12: 'Rs. 400 અથવા કુલ મૂલ્યના 10% માંથી જે વધુ હોય',
    pHigher3: 'Rs. 700 અથવા કુલ મૂલ્યના 10% માંથી જે વધુ હોય',
    r2: "ડ્રાઇવરે એપમાં 'Complete Journey' કર્યું નહીં કે ગ્રાહક સહાય મારફતે કરાવ્યું નહીં.",
    r3: 'App માં પસંદ કરેલી કારથી અલગ કાર ગ્રાહકને મોકલવી.',
    r4: 'Driver App માં પસંદ કરેલા ડ્રાઇવરથી અલગ Driver ગ્રાહકને મોકલવો.',
    r5: 'એવી sedan કાર મોકલી જેમાં ન તો યોગ્ય બૂટ સ્પેસ (ડિગ્ગી) છે કે ન carrier. CNG કારોમાં આવું બની શકે — જો CNG સીડાનના બૂટમાં લગાવેલ હોય તો સામાન માટે જગ્યા હોવી જોઈએ.',
    r6: 'કાર સાફ ન હતી.',
    r7: 'કાર સારી condition માં ન હતી.',
    r8: 'ડ્રાઇવરે ગેરવર્તન કર્યું.',
  ),
  'mr': _PC(
    title: 'पेनल्टी',
    intro: 'प्रिय पार्टनर,\n\nतुम्हाला माहीत आहेच, चांगली सेवा आपल्या व्यवसायाच्या यशाची गुरुकिल्ली आहे. आमच्यासमोर असे काही प्रकरणे आली आहेत जिथे पार्टनर्सनी अयोग्य सेवा दिली आहे. म्हणून, विविध अयोग्य सेवांसाठी दंड निश्चित करण्यासाठी, Gora ने पार्टनर्ससोबत सर्व्हिस लेव्हल अ‍ॅग्रीमेंट (SLA) अपडेट केले आहे.\n\nकृपया खालील यादी काळजीपूर्वक पहा आणि ग्राहकाला सर्वोत्तम सेवा द्या, जेणेकरून तुमच्या खात्यावर कोणतीही Penalty लागणार नाही.',
    footer: 'Gora अयोग्य कृतीवर योग्य पावले उचलते. कोणत्याही वादात Gora चा निर्णय अंतिम असेल.',
    sNo: 'क्र.', actionHdr: 'अयोग्य सेवा (Action)',
    r1: 'बुकिंग स्वीकारल्यानंतर रद्द करणे (Cancellation)',
    subI: 'i) प्रस्थानाच्या 12 तास आधी Cancellation',
    subII: 'ii) प्रस्थानाच्या 12 तासांच्या आत Cancellation',
    subIII: 'iii) प्रस्थानाच्या 3 तासांच्या आत Cancellation',
    subIV: 'iv) स्वीकार (Accept) च्या 30 मिनिटांच्या आत Cancellation',
    pLower: 'Rs. 400 किंवा एकूण मूल्याच्या 10% पैकी जे कमी असेल',
    pHigher12: 'Rs. 400 किंवा एकूण मूल्याच्या 10% पैकी जे जास्त असेल',
    pHigher3: 'Rs. 700 किंवा एकूण मूल्याच्या 10% पैकी जे जास्त असेल',
    r2: "ड्रायव्हरने अ‍ॅपमध्ये 'Complete Journey' केले नाही किंवा ग्राहक सहाय्यामार्फत करवले नाही.",
    r3: 'App मध्ये निवडलेल्या कारपेक्षा वेगळी कार ग्राहकाला पाठवणे.',
    r4: 'Driver App मध्ये निवडलेल्या ड्रायव्हरपेक्षा वेगळा Driver ग्राहकाला पाठवणे.',
    r5: 'अशी sedan कार पाठवली जिच्यात ना योग्य बूट स्पेस (डिग्गी) आहे ना carrier. CNG कारमध्ये असे होऊ शकते — CNG सिडानच्या बूटमध्ये बसवली असल्यास सामानासाठी जागा असावी.',
    r6: 'कार स्वच्छ नव्हती.',
    r7: 'कार चांगल्या condition मध्ये नव्हती.',
    r8: 'ड्रायव्हरने गैरवर्तन केले.',
  ),
  'bn': _PC(
    title: 'পেনাল্টি',
    intro: 'প্রিয় পার্টনার,\n\nআপনি জানেন, ভালো পরিষেবা আমাদের ব্যবসার সাফল্যের চাবিকাঠি। আমাদের সামনে এমন কিছু ঘটনা এসেছে যেখানে পার্টনাররা অনুপযুক্ত পরিষেবা দিয়েছেন। তাই, বিভিন্ন অনুপযুক্ত পরিষেবার জন্য জরিমানা নির্ধারণ করতে, Gora পার্টনারদের সাথে সার্ভিস লেভেল এগ্রিমেন্ট (SLA) আপডেট করেছে।\n\nঅনুগ্রহ করে নিচের তালিকাটি খুব যত্নসহকারে দেখুন এবং গ্রাহককে সেরা পরিষেবা দিন, যাতে আপনার অ্যাকাউন্টে কোনো Penalty না লাগে।',
    footer: 'Gora অনুপযুক্ত পদক্ষেপে যথাযথ ব্যবস্থা নেয়। যেকোনো বিরোধে Gora-এর সিদ্ধান্তই চূড়ান্ত।',
    sNo: 'ক্র.', actionHdr: 'অনুপযুক্ত পরিষেবা (Action)',
    r1: 'বুকিং গ্রহণের পর বাতিল করা (Cancellation)',
    subI: 'i) যাত্রার 12 ঘণ্টা আগে Cancellation',
    subII: 'ii) যাত্রার 12 ঘণ্টার মধ্যে Cancellation',
    subIII: 'iii) যাত্রার 3 ঘণ্টার মধ্যে Cancellation',
    subIV: 'iv) গ্রহণের (Accept) 30 মিনিটের মধ্যে Cancellation',
    pLower: 'Rs. 400 বা মোট মূল্যের 10%-এর মধ্যে যেটি কম',
    pHigher12: 'Rs. 400 বা মোট মূল্যের 10%-এর মধ্যে যেটি বেশি',
    pHigher3: 'Rs. 700 বা মোট মূল্যের 10%-এর মধ্যে যেটি বেশি',
    r2: "ড্রাইভার অ্যাপে 'Complete Journey' করেননি বা গ্রাহক সহায়তার মাধ্যমে করাননি।",
    r3: 'App-এ নির্বাচিত গাড়ির থেকে ভিন্ন গাড়ি গ্রাহককে পাঠানো।',
    r4: 'Driver App-এ নির্বাচিত ড্রাইভারের থেকে ভিন্ন Driver গ্রাহককে পাঠানো।',
    r5: 'এমন sedan গাড়ি পাঠানো যাতে সঠিক বুট স্পেস (ডিগি) বা carrier কোনোটাই নেই। CNG গাড়িতে এমন হতে পারে — CNG সেডানের বুটে লাগানো থাকলে মালপত্রের জন্য জায়গা থাকতে হবে।',
    r6: 'গাড়ি পরিষ্কার ছিল না।',
    r7: 'গাড়ি ভালো condition-এ ছিল না।',
    r8: 'ড্রাইভার দুর্ব্যবহার করেছেন।',
  ),
  'pa': _PC(
    title: 'ਪੈਨਲਟੀ',
    intro: 'ਪਿਆਰੇ ਪਾਰਟਨਰ,\n\nਜਿਵੇਂ ਤੁਸੀਂ ਜਾਣਦੇ ਹੋ, ਵਧੀਆ ਸੇਵਾ ਸਾਡੇ ਕਾਰੋਬਾਰ ਦੀ ਸਫਲਤਾ ਦੀ ਕੁੰਜੀ ਹੈ। ਸਾਡੇ ਸਾਹਮਣੇ ਕੁਝ ਅਜਿਹੇ ਮਾਮਲੇ ਆਏ ਹਨ ਜਿੱਥੇ ਪਾਰਟਨਰਾਂ ਨੇ ਅਣਉਚਿਤ ਸੇਵਾ ਦਿੱਤੀ ਹੈ। ਇਸ ਲਈ, ਵੱਖ-ਵੱਖ ਅਣਉਚਿਤ ਸੇਵਾਵਾਂ ਲਈ ਜੁਰਮਾਨਾ ਤੈਅ ਕਰਨ ਲਈ, Gora ਨੇ ਪਾਰਟਨਰਾਂ ਨਾਲ ਸਰਵਿਸ ਲੈਵਲ ਐਗਰੀਮੈਂਟ (SLA) ਅੱਪਡੇਟ ਕੀਤਾ ਹੈ।\n\nਕਿਰਪਾ ਕਰਕੇ ਹੇਠਾਂ ਦਿੱਤੀ ਸੂਚੀ ਧਿਆਨ ਨਾਲ ਵੇਖੋ ਅਤੇ ਗਾਹਕ ਨੂੰ ਸਭ ਤੋਂ ਵਧੀਆ ਸੇਵਾ ਦਿਓ, ਤਾਂ ਜੋ ਤੁਹਾਡੇ ਖਾਤੇ ਵਿੱਚ ਕੋਈ Penalty ਨਾ ਲੱਗੇ।',
    footer: 'Gora ਅਣਉਚਿਤ ਕਾਰਵਾਈ ਤੇ ਉਚਿਤ ਕਦਮ ਚੁੱਕਦਾ ਹੈ। ਕਿਸੇ ਵੀ ਵਿਵਾਦ ਵਿੱਚ Gora ਦਾ ਫੈਸਲਾ ਅੰਤਿਮ ਹੋਵੇਗਾ।',
    sNo: 'ਲੜੀ', actionHdr: 'ਅਣਉਚਿਤ ਸੇਵਾ (Action)',
    r1: 'ਬੁਕਿੰਗ ਸਵੀਕਾਰ ਕਰਨ ਤੋਂ ਬਾਅਦ ਰੱਦ ਕਰਨਾ (Cancellation)',
    subI: 'i) ਰਵਾਨਗੀ ਤੋਂ 12 ਘੰਟੇ ਪਹਿਲਾਂ Cancellation',
    subII: 'ii) ਰਵਾਨਗੀ ਦੇ 12 ਘੰਟਿਆਂ ਦੇ ਅੰਦਰ Cancellation',
    subIII: 'iii) ਰਵਾਨਗੀ ਦੇ 3 ਘੰਟਿਆਂ ਦੇ ਅੰਦਰ Cancellation',
    subIV: 'iv) ਸਵੀਕਾਰ (Accept) ਦੇ 30 ਮਿੰਟਾਂ ਦੇ ਅੰਦਰ Cancellation',
    pLower: 'Rs. 400 ਜਾਂ ਕੁੱਲ ਮੁੱਲ ਦੇ 10% ਵਿੱਚੋਂ ਜੋ ਘੱਟ ਹੋਵੇ',
    pHigher12: 'Rs. 400 ਜਾਂ ਕੁੱਲ ਮੁੱਲ ਦੇ 10% ਵਿੱਚੋਂ ਜੋ ਵੱਧ ਹੋਵੇ',
    pHigher3: 'Rs. 700 ਜਾਂ ਕੁੱਲ ਮੁੱਲ ਦੇ 10% ਵਿੱਚੋਂ ਜੋ ਵੱਧ ਹੋਵੇ',
    r2: "ਡਰਾਈਵਰ ਨੇ ਐਪ ਵਿੱਚ 'Complete Journey' ਨਹੀਂ ਕੀਤਾ ਜਾਂ ਗਾਹਕ ਸਹਾਇਤਾ ਰਾਹੀਂ ਨਹੀਂ ਕਰਵਾਇਆ।",
    r3: 'App ਵਿੱਚ ਚੁਣੀ ਕਾਰ ਤੋਂ ਵੱਖਰੀ ਕਾਰ ਗਾਹਕ ਨੂੰ ਭੇਜਣਾ।',
    r4: 'Driver App ਵਿੱਚ ਚੁਣੇ ਡਰਾਈਵਰ ਤੋਂ ਵੱਖਰਾ Driver ਗਾਹਕ ਨੂੰ ਭੇਜਣਾ।',
    r5: 'ਅਜਿਹੀ sedan ਕਾਰ ਭੇਜੀ ਜਿਸ ਵਿੱਚ ਨਾ ਤਾਂ ਸਹੀ ਬੂਟ ਸਪੇਸ (ਡਿੱਗੀ) ਹੈ ਨਾ carrier। CNG ਕਾਰਾਂ ਨਾਲ ਇਹ ਹੋ ਸਕਦਾ ਹੈ — ਜੇ CNG ਸੀਡਾਨ ਦੇ ਬੂਟ ਵਿੱਚ ਲੱਗੀ ਹੋਵੇ ਤਾਂ ਸਮਾਨ ਲਈ ਜਗ੍ਹਾ ਹੋਣੀ ਚਾਹੀਦੀ ਹੈ।',
    r6: 'ਕਾਰ ਸਾਫ਼ ਨਹੀਂ ਸੀ।',
    r7: 'ਕਾਰ ਚੰਗੀ condition ਵਿੱਚ ਨਹੀਂ ਸੀ।',
    r8: 'ਡਰਾਈਵਰ ਨੇ ਦੁਰਵਿਵਹਾਰ ਕੀਤਾ।',
  ),
  'ta': _PC(
    title: 'அபராதம்',
    intro: 'அன்புள்ள பார்ட்னர்,\n\nஉங்களுக்குத் தெரிந்தபடி, நல்ல சேவை நமது வணிக வெற்றியின் திறவுகோல். பார்ட்னர்கள் முறையற்ற சேவை வழங்கிய சில வழக்குகள் எங்கள் கவனத்திற்கு வந்துள்ளன. எனவே, பல்வேறு முறையற்ற சேவைகளுக்கு அபராதத்தை வரையறுக்க, Gora பார்ட்னர்களுடன் சர்வீஸ் லெவல் அக்ரிமெண்ட் (SLA)-ஐ புதுப்பித்துள்ளது.\n\nதயவுசெய்து கீழே உள்ள பட்டியலை மிகவும் கவனமாகப் பார்த்து, வாடிக்கையாளருக்குச் சிறந்த சேவையை வழங்குங்கள், அப்போது உங்கள் கணக்கில் எந்த Penalty-யும் விழாது.',
    footer: 'முறையற்ற செயலுக்கு Gora உரிய நடவடிக்கை எடுக்கும். எந்த சர்ச்சையிலும் Gora-வின் முடிவே இறுதியானது.',
    sNo: 'எண்.', actionHdr: 'முறையற்ற சேவை (Action)',
    r1: 'புக்கிங்கை ஏற்ற பிறகு ரத்து செய்தல் (Cancellation)',
    subI: 'i) புறப்படுவதற்கு 12 மணி நேரத்திற்கு முன் Cancellation',
    subII: 'ii) புறப்படுவதற்கு 12 மணி நேரத்திற்குள் Cancellation',
    subIII: 'iii) புறப்படுவதற்கு 3 மணி நேரத்திற்குள் Cancellation',
    subIV: 'iv) ஏற்று (Accept) 30 நிமிடத்திற்குள் Cancellation',
    pLower: 'Rs. 400 அல்லது மொத்த மதிப்பில் 10% — எது குறைவோ அது',
    pHigher12: 'Rs. 400 அல்லது மொத்த மதிப்பில் 10% — எது அதிகமோ அது',
    pHigher3: 'Rs. 700 அல்லது மொத்த மதிப்பில் 10% — எது அதிகமோ அது',
    r2: "டிரைவர் ஆப்பில் 'Complete Journey' செய்யவில்லை அல்லது வாடிக்கையாளர் ஆதரவு மூலம் செய்யவைக்கவில்லை.",
    r3: 'App-இல் தேர்ந்தெடுத்த காரிலிருந்து வேறு காரை வாடிக்கையாளருக்கு அனுப்புதல்.',
    r4: 'Driver App-இல் தேர்ந்தெடுத்த டிரைவரிலிருந்து வேறு Driver-ஐ அனுப்புதல்.',
    r5: 'சரியான பூட் ஸ்பேஸ் (டிக்கி) அல்லது carrier இல்லாத sedan காரை அனுப்புதல். CNG கார்களில் இது நடக்கலாம் — CNG செடானின் பூட்டில் பொருத்தப்பட்டால், சாமான்களுக்கு இடம் இருக்க வேண்டும்.',
    r6: 'கார் சுத்தமாக இல்லை.',
    r7: 'கார் நல்ல condition-இல் இல்லை.',
    r8: 'டிரைவர் தவறாக நடந்துகொண்டார்.',
  ),
  'te': _PC(
    title: 'పెనాల్టీ',
    intro: 'ప్రియ పార్టనర్,\n\nమీకు తెలిసినట్లే, మంచి సేవ మన వ్యాపార విజయానికి కీలకం. పార్టనర్లు అనుచిత సేవలు అందించిన కొన్ని సందర్భాలు మా దృష్టికి వచ్చాయి. అందువల్ల, వివిధ అనుచిత సేవలకు జరిమానాను నిర్వచించడానికి, Gora పార్టనర్లతో సర్వీస్ లెవెల్ అగ్రిమెంట్ (SLA)ని అప్‌డేట్ చేసింది.\n\nదయచేసి కింది జాబితాను చాలా జాగ్రత్తగా చూడండి మరియు కస్టమర్‌కు ఉత్తమ సేవను అందించండి, తద్వారా మీ ఖాతాలో ఎలాంటి Penalty పడదు.',
    footer: 'అనుచిత చర్యపై Gora తగిన చర్యలు తీసుకుంటుంది. ఏదైనా వివాదంలో Gora నిర్ణయమే అంతిమం.',
    sNo: 'సంఖ్య', actionHdr: 'అనుచిత సేవ (Action)',
    r1: 'బుకింగ్ అంగీకరించిన తర్వాత రద్దు చేయడం (Cancellation)',
    subI: 'i) బయలుదేరడానికి 12 గంటల ముందు Cancellation',
    subII: 'ii) బయలుదేరడానికి 12 గంటల లోపు Cancellation',
    subIII: 'iii) బయలుదేరడానికి 3 గంటల లోపు Cancellation',
    subIV: 'iv) అంగీకరించిన (Accept) 30 నిమిషాల లోపు Cancellation',
    pLower: 'Rs. 400 లేదా మొత్తం విలువలో 10% — ఏది తక్కువైతే అది',
    pHigher12: 'Rs. 400 లేదా మొత్తం విలువలో 10% — ఏది ఎక్కువైతే అది',
    pHigher3: 'Rs. 700 లేదా మొత్తం విలువలో 10% — ఏది ఎక్కువైతే అది',
    r2: "డ్రైవర్ యాప్‌లో 'Complete Journey' చేయలేదు లేదా కస్టమర్ సపోర్ట్ ద్వారా చేయించలేదు.",
    r3: 'App లో ఎంచుకున్న కారు కాకుండా వేరే కారును కస్టమర్‌కు పంపడం.',
    r4: 'Driver App లో ఎంచుకున్న డ్రైవర్ కాకుండా వేరే Driver ను పంపడం.',
    r5: 'సరైన బూట్ స్పేస్ (డిక్కీ) లేదా carrier లేని sedan కారును పంపడం. CNG కార్లలో ఇది జరగవచ్చు — CNG సెడాన్ బూట్‌లో అమర్చితే, సామానుకు స్థలం ఉండాలి.',
    r6: 'కారు శుభ్రంగా లేదు.',
    r7: 'కారు మంచి condition లో లేదు.',
    r8: 'డ్రైవర్ దుర్వర్తన చేశాడు.',
  ),
  'kn': _PC(
    title: 'ದಂಡ',
    intro: 'ಆತ್ಮೀಯ ಪಾರ್ಟ್‌ನರ್,\n\nನಿಮಗೆ ತಿಳಿದಿರುವಂತೆ, ಉತ್ತಮ ಸೇವೆ ನಮ್ಮ ವ್ಯಾಪಾರದ ಯಶಸ್ಸಿನ ಕೀಲಿಕೈ. ಪಾರ್ಟ್‌ನರ್‌ಗಳು ಅನುಚಿತ ಸೇವೆ ನೀಡಿದ ಕೆಲವು ಪ್ರಕರಣಗಳು ನಮ್ಮ ಗಮನಕ್ಕೆ ಬಂದಿವೆ. ಆದ್ದರಿಂದ, ವಿವಿಧ ಅನುಚಿತ ಸೇವೆಗಳಿಗೆ ದಂಡವನ್ನು ವ್ಯಾಖ್ಯಾನಿಸಲು, Gora ಪಾರ್ಟ್‌ನರ್‌ಗಳೊಂದಿಗೆ ಸರ್ವಿಸ್ ಲೆವೆಲ್ ಅಗ್ರಿಮೆಂಟ್ (SLA) ಅನ್ನು ನವೀಕರಿಸಿದೆ.\n\nದಯವಿಟ್ಟು ಕೆಳಗಿನ ಪಟ್ಟಿಯನ್ನು ಬಹಳ ಎಚ್ಚರಿಕೆಯಿಂದ ನೋಡಿ ಮತ್ತು ಗ್ರಾಹಕರಿಗೆ ಅತ್ಯುತ್ತಮ ಸೇವೆ ನೀಡಿ, ಇದರಿಂದ ನಿಮ್ಮ ಖಾತೆಗೆ ಯಾವುದೇ Penalty ಬೀಳುವುದಿಲ್ಲ.',
    footer: 'ಅನುಚಿತ ಕ್ರಮದ ಮೇಲೆ Gora ಸೂಕ್ತ ಕ್ರಮ ಕೈಗೊಳ್ಳುತ್ತದೆ. ಯಾವುದೇ ವಿವಾದದಲ್ಲಿ Gora ನಿರ್ಧಾರವೇ ಅಂತಿಮ.',
    sNo: 'ಕ್ರ.ಸಂ.', actionHdr: 'ಅನುಚಿತ ಸೇವೆ (Action)',
    r1: 'ಬುಕಿಂಗ್ ಸ್ವೀಕರಿಸಿದ ನಂತರ ರದ್ದುಗೊಳಿಸುವುದು (Cancellation)',
    subI: 'i) ಪ್ರಯಾಣಕ್ಕೆ 12 ಗಂಟೆ ಮೊದಲು Cancellation',
    subII: 'ii) ಪ್ರಯಾಣದ 12 ಗಂಟೆಯೊಳಗೆ Cancellation',
    subIII: 'iii) ಪ್ರಯಾಣದ 3 ಗಂಟೆಯೊಳಗೆ Cancellation',
    subIV: 'iv) ಸ್ವೀಕರಿಸಿದ (Accept) 30 ನಿಮಿಷದೊಳಗೆ Cancellation',
    pLower: 'Rs. 400 ಅಥವಾ ಒಟ್ಟು ಮೌಲ್ಯದ 10% — ಯಾವುದು ಕಡಿಮೆಯೋ ಅದು',
    pHigher12: 'Rs. 400 ಅಥವಾ ಒಟ್ಟು ಮೌಲ್ಯದ 10% — ಯಾವುದು ಹೆಚ್ಚೋ ಅದು',
    pHigher3: 'Rs. 700 ಅಥವಾ ಒಟ್ಟು ಮೌಲ್ಯದ 10% — ಯಾವುದು ಹೆಚ್ಚೋ ಅದು',
    r2: "ಡ್ರೈವರ್ ಆ್ಯಪ್‌ನಲ್ಲಿ 'Complete Journey' ಮಾಡಲಿಲ್ಲ ಅಥವಾ ಗ್ರಾಹಕ ಬೆಂಬಲದ ಮೂಲಕ ಮಾಡಿಸಲಿಲ್ಲ.",
    r3: 'App ನಲ್ಲಿ ಆಯ್ಕೆ ಮಾಡಿದ ಕಾರ್‌ಗಿಂತ ಬೇರೆ ಕಾರ್ ಅನ್ನು ಗ್ರಾಹಕರಿಗೆ ಕಳುಹಿಸುವುದು.',
    r4: 'Driver App ನಲ್ಲಿ ಆಯ್ಕೆ ಮಾಡಿದ ಡ್ರೈವರ್‌ಗಿಂತ ಬೇರೆ Driver ಅನ್ನು ಕಳುಹಿಸುವುದು.',
    r5: 'ಸರಿಯಾದ ಬೂಟ್ ಸ್ಪೇಸ್ (ಡಿಕ್ಕಿ) ಅಥವಾ carrier ಇಲ್ಲದ sedan ಕಾರ್ ಕಳುಹಿಸುವುದು. CNG ಕಾರ್‌ಗಳಲ್ಲಿ ಇದು ಆಗಬಹುದು — CNG ಅನ್ನು ಸೆಡಾನ್ ಬೂಟ್‌ನಲ್ಲಿ ಅಳವಡಿಸಿದರೆ, ಸಾಮಾನುಗಳಿಗೆ ಸ್ಥಳ ಇರಬೇಕು.',
    r6: 'ಕಾರ್ ಸ್ವಚ್ಛವಾಗಿರಲಿಲ್ಲ.',
    r7: 'ಕಾರ್ ಉತ್ತಮ condition ನಲ್ಲಿ ಇರಲಿಲ್ಲ.',
    r8: 'ಡ್ರೈವರ್ ಅಸಭ್ಯವಾಗಿ ವರ್ತಿಸಿದರು.',
  ),
  'ml': _PC(
    title: 'പിഴ',
    intro: 'പ്രിയ പാർട്ണർ,\n\nനിങ്ങൾക്കറിയാവുന്നതുപോലെ, നല്ല സേവനമാണ് നമ്മുടെ ബിസിനസ്സിന്റെ വിജയത്തിന്റെ താക്കോൽ. പാർട്ണർമാർ അനുചിതമായ സേവനം നൽകിയ ചില സംഭവങ്ങൾ ഞങ്ങളുടെ ശ്രദ്ധയിൽപ്പെട്ടിട്ടുണ്ട്. അതിനാൽ, വിവിധ അനുചിത സേവനങ്ങൾക്ക് പിഴ നിർവചിക്കാൻ, Gora പാർട്ണർമാരുമായി സർവീസ് ലെവൽ അഗ്രിമെന്റ് (SLA) അപ്ഡേറ്റ് ചെയ്തിരിക്കുന്നു.\n\nദയവായി താഴെയുള്ള പട്ടിക വളരെ ശ്രദ്ധയോടെ നോക്കുകയും ഉപഭോക്താവിന് മികച്ച സേവനം നൽകുകയും ചെയ്യുക, അങ്ങനെ നിങ്ങളുടെ അക്കൗണ്ടിൽ ഒരു Penalty-യും വരില്ല.',
    footer: 'അനുചിതമായ നടപടിക്ക് Gora ഉചിതമായ നടപടികൾ സ്വീകരിക്കും. ഏതൊരു തർക്കത്തിലും Gora-യുടെ തീരുമാനമാണ് അന്തിമം.',
    sNo: 'ക്രമം', actionHdr: 'അനുചിത സേവനം (Action)',
    r1: 'ബുക്കിംഗ് സ്വീകരിച്ചശേഷം റദ്ദാക്കൽ (Cancellation)',
    subI: 'i) പുറപ്പെടലിന് 12 മണിക്കൂർ മുമ്പ് Cancellation',
    subII: 'ii) പുറപ്പെടലിന്റെ 12 മണിക്കൂറിനുള്ളിൽ Cancellation',
    subIII: 'iii) പുറപ്പെടലിന്റെ 3 മണിക്കൂറിനുള്ളിൽ Cancellation',
    subIV: 'iv) സ്വീകരിച്ച (Accept) 30 മിനിറ്റിനുള്ളിൽ Cancellation',
    pLower: 'Rs. 400 അല്ലെങ്കിൽ ആകെ മൂല്യത്തിന്റെ 10% — ഏതാണോ കുറവ്',
    pHigher12: 'Rs. 400 അല്ലെങ്കിൽ ആകെ മൂല്യത്തിന്റെ 10% — ഏതാണോ കൂടുതൽ',
    pHigher3: 'Rs. 700 അല്ലെങ്കിൽ ആകെ മൂല്യത്തിന്റെ 10% — ഏതാണോ കൂടുതൽ',
    r2: "ഡ്രൈവർ ആപ്പിൽ 'Complete Journey' ചെയ്തില്ല അല്ലെങ്കിൽ കസ്റ്റമർ സപ്പോർട്ട് വഴി ചെയ്യിച്ചില്ല.",
    r3: 'App-ൽ തിരഞ്ഞെടുത്ത കാറിൽ നിന്ന് വ്യത്യസ്തമായ കാർ ഉപഭോക്താവിന് അയയ്ക്കൽ.',
    r4: 'Driver App-ൽ തിരഞ്ഞെടുത്ത ഡ്രൈവറിൽ നിന്ന് വ്യത്യസ്തമായ Driver-നെ അയയ്ക്കൽ.',
    r5: 'ശരിയായ ബൂട്ട് സ്പേസ് (ഡിക്കി) അല്ലെങ്കിൽ carrier ഇല്ലാത്ത sedan കാർ അയയ്ക്കൽ. CNG കാറുകളിൽ ഇത് സംഭവിക്കാം — CNG സെഡാൻ ബൂട്ടിൽ ഘടിപ്പിച്ചാൽ, ലഗേജിന് സ്ഥലം വേണം.',
    r6: 'കാർ വൃത്തിയായിരുന്നില്ല.',
    r7: 'കാർ നല്ല condition-ൽ ആയിരുന്നില്ല.',
    r8: 'ഡ്രൈവർ മോശമായി പെരുമാറി.',
  ),
  'or': _PC(
    title: 'ପେନାଲ୍ଟି',
    intro: 'ପ୍ରିୟ ପାର୍ଟନର,\n\nଆପଣ ଜାଣନ୍ତି, ଭଲ ସେବା ଆମ ବ୍ୟବସାୟ ସଫଳତାର ଚାବିକାଠି। ଆମ ସାମ୍ନାକୁ ଏମିତି କିଛି ମାମଲା ଆସିଛି ଯେଉଁଠି ପାର୍ଟନରମାନେ ଅନୁପଯୁକ୍ତ ସେବା ଦେଇଛନ୍ତି। ତେଣୁ, ବିଭିନ୍ନ ଅନୁପଯୁକ୍ତ ସେବା ପାଇଁ ଜରିମାନା ନିର୍ଦ୍ଧାରଣ କରିବାକୁ, Gora ପାର୍ଟନରମାନଙ୍କ ସହ ସର୍ଭିସ ଲେଭେଲ ଏଗ୍ରିମେଣ୍ଟ (SLA) ଅପଡେଟ କରିଛି।\n\nଦୟାକରି ନିମ୍ନ ତାଲିକାକୁ ବହୁତ ଯତ୍ନର ସହ ଦେଖନ୍ତୁ ଏବଂ ଗ୍ରାହକଙ୍କୁ ସର୍ବୋତ୍ତମ ସେବା ଦିଅନ୍ତୁ, ଯାହା ଫଳରେ ଆପଣଙ୍କ ଖାତାରେ କୌଣସି Penalty ଲାଗିବ ନାହିଁ।',
    footer: 'ଅନୁପଯୁକ୍ତ କାର୍ଯ୍ୟ ଉପରେ Gora ଉପଯୁକ୍ତ ପଦକ୍ଷେପ ନେଇଥାଏ। ଯେକୌଣସି ବିବାଦରେ Gora ର ନିଷ୍ପତ୍ତି ଅନ୍ତିମ ହେବ।',
    sNo: 'କ୍ର.', actionHdr: 'ଅନୁପଯୁକ୍ତ ସେବା (Action)',
    r1: 'ବୁକିଂ ଗ୍ରହଣ କରିବା ପରେ ବାତିଲ କରିବା (Cancellation)',
    subI: 'i) ପ୍ରସ୍ଥାନର 12 ଘଣ୍ଟା ପୂର୍ବରୁ Cancellation',
    subII: 'ii) ପ୍ରସ୍ଥାନର 12 ଘଣ୍ଟା ମଧ୍ୟରେ Cancellation',
    subIII: 'iii) ପ୍ରସ୍ଥାନର 3 ଘଣ୍ଟା ମଧ୍ୟରେ Cancellation',
    subIV: 'iv) ଗ୍ରହଣ (Accept) ର 30 ମିନିଟ ମଧ୍ୟରେ Cancellation',
    pLower: 'Rs. 400 କିମ୍ବା ମୋଟ ମୂଲ୍ୟର 10% ମଧ୍ୟରୁ ଯାହା କମ୍',
    pHigher12: 'Rs. 400 କିମ୍ବା ମୋଟ ମୂଲ୍ୟର 10% ମଧ୍ୟରୁ ଯାହା ଅଧିକ',
    pHigher3: 'Rs. 700 କିମ୍ବା ମୋଟ ମୂଲ୍ୟର 10% ମଧ୍ୟରୁ ଯାହା ଅଧିକ',
    r2: "ଡ୍ରାଇଭର ଆପରେ 'Complete Journey' କରିନାହାଁନ୍ତି କିମ୍ବା ଗ୍ରାହକ ସହାୟତା ମାଧ୍ୟମରେ କରାଇନାହାଁନ୍ତି।",
    r3: 'App ରେ ବଛା କାର ଠାରୁ ଅଲଗା କାର ଗ୍ରାହକଙ୍କୁ ପଠାଇବା।',
    r4: 'Driver App ରେ ବଛା ଡ୍ରାଇଭର ଠାରୁ ଅଲଗା Driver ପଠାଇବା।',
    r5: 'ଏମିତି sedan କାର ପଠାଗଲା ଯେଉଁଥିରେ ନା ଠିକ ବୁଟ ସ୍ପେସ (ଡିଗି) ଅଛି ନା carrier। CNG କାରରେ ଏମିତି ହୋଇପାରେ — CNG ସିଡାନ ବୁଟରେ ଲଗାଯାଇଥିଲେ ଜିନିଷ ପାଇଁ ସ୍ଥାନ ରହିବା ଆବଶ୍ୟକ।',
    r6: 'କାର ସଫା ନ ଥିଲା।',
    r7: 'କାର ଭଲ condition ରେ ନ ଥିଲା।',
    r8: 'ଡ୍ରାଇଭର ଦୁର୍ବ୍ୟବହାର କଲେ।',
  ),
  'ur': _PC(
    title: 'پینلٹی',
    intro: 'محترم پارٹنر،\n\nجیسا کہ آپ جانتے ہیں، اچھی سروس ہمارے کاروبار کی کامیابی کی کنجی ہے۔ ہمارے سامنے کچھ ایسے معاملات آئے ہیں جہاں پارٹنرز نے نامناسب سروس فراہم کی ہے۔ اس لیے، مختلف نامناسب سروسز کے لیے جرمانہ مقرر کرنے کے لیے، Gora نے پارٹنرز کے ساتھ سروس لیول ایگریمنٹ (SLA) کو اپ ڈیٹ کیا ہے۔\n\nبراہ کرم نیچے دی گئی فہرست کو بہت احتیاط سے دیکھیں اور گاہک کو بہترین سروس دیں، تاکہ آپ کے اکاؤنٹ پر کوئی Penalty نہ لگے۔',
    footer: 'نامناسب کارروائی پر Gora مناسب اقدامات کرتا ہے۔ کسی بھی تنازع میں Gora کا فیصلہ حتمی ہوگا۔',
    sNo: 'نمبر', actionHdr: 'نامناسب سروس (Action)',
    r1: 'بکنگ قبول کرنے کے بعد منسوخ کرنا (Cancellation)',
    subI: 'i) روانگی سے 12 گھنٹے پہلے Cancellation',
    subII: 'ii) روانگی کے 12 گھنٹے کے اندر Cancellation',
    subIII: 'iii) روانگی کے 3 گھنٹے کے اندر Cancellation',
    subIV: 'iv) قبول (Accept) کے 30 منٹ کے اندر Cancellation',
    pLower: 'Rs. 400 یا کل قیمت کا 10% — جو بھی کم ہو',
    pHigher12: 'Rs. 400 یا کل قیمت کا 10% — جو بھی زیادہ ہو',
    pHigher3: 'Rs. 700 یا کل قیمت کا 10% — جو بھی زیادہ ہو',
    r2: "ڈرائیور نے ایپ میں 'Complete Journey' نہیں کیا یا کسٹمر سپورٹ کے ذریعے نہیں کروایا۔",
    r3: 'App میں منتخب کار سے مختلف کار گاہک کو بھیجنا۔',
    r4: 'Driver App میں منتخب ڈرائیور سے مختلف Driver گاہک کو بھیجنا۔',
    r5: 'ایسی sedan کار بھیجی جس میں نہ مناسب بوٹ اسپیس (ڈگی) ہے نہ carrier۔ CNG کاروں میں ایسا ہو سکتا ہے — اگر CNG سیڈان کے بوٹ میں لگی ہو تو سامان کے لیے جگہ ہونی چاہیے۔',
    r6: 'کار صاف نہیں تھی۔',
    r7: 'کار اچھی condition میں نہیں تھی۔',
    r8: 'ڈرائیور نے بدتمیزی کی۔',
  ),
  'as': _PC(
    title: 'পেনাল্টি',
    intro: 'প্ৰিয় পাৰ্টনাৰ,\n\nআপুনি জানেই, ভাল সেৱা আমাৰ ব্যৱসায়ৰ সফলতাৰ চাবিকাঠি। আমাৰ সন্মুখলৈ এনে কিছুমান ঘটনা আহিছে য\'ত পাৰ্টনাৰসকলে অনুপযুক্ত সেৱা আগবঢ়াইছে। সেয়েহে, বিভিন্ন অনুপযুক্ত সেৱাৰ বাবে জৰিমনা নিৰ্ধাৰণ কৰিবলৈ, Gora-ই পাৰ্টনাৰসকলৰ সৈতে চাৰ্ভিচ লেভেল এগ্ৰিমেণ্ট (SLA) আপডেট কৰিছে।\n\nঅনুগ্ৰহ কৰি তলৰ তালিকাখন বৰ মনোযোগেৰে চাওক আৰু গ্ৰাহকক সৰ্বোত্তম সেৱা দিয়ক, যাতে আপোনাৰ একাউণ্টত কোনো Penalty নালাগে।',
    footer: 'অনুপযুক্ত কাৰ্যৰ ওপৰত Gora-ই উপযুক্ত ব্যৱস্থা লয়। যিকোনো বিবাদত Gora-ৰ সিদ্ধান্তই চূড়ান্ত।',
    sNo: 'ক্ৰ.', actionHdr: 'অনুপযুক্ত সেৱা (Action)',
    r1: 'বুকিং গ্ৰহণ কৰাৰ পিছত বাতিল কৰা (Cancellation)',
    subI: 'i) প্ৰস্থানৰ 12 ঘণ্টা আগতে Cancellation',
    subII: 'ii) প্ৰস্থানৰ 12 ঘণ্টাৰ ভিতৰত Cancellation',
    subIII: 'iii) প্ৰস্থানৰ 3 ঘণ্টাৰ ভিতৰত Cancellation',
    subIV: 'iv) গ্ৰহণ (Accept) ৰ 30 মিনিটৰ ভিতৰত Cancellation',
    pLower: 'Rs. 400 বা মুঠ মূল্যৰ 10% — যিটো কম',
    pHigher12: 'Rs. 400 বা মুঠ মূল্যৰ 10% — যিটো বেছি',
    pHigher3: 'Rs. 700 বা মুঠ মূল্যৰ 10% — যিটো বেছি',
    r2: "ড্ৰাইভাৰে এপত 'Complete Journey' নকৰিলে বা গ্ৰাহক সহায়ৰ জৰিয়তে নকৰালে।",
    r3: 'App ত বাছনি কৰা গাড়ীতকৈ বেলেগ গাড়ী গ্ৰাহকক পঠোৱা।',
    r4: 'Driver App ত বাছনি কৰা ড্ৰাইভাৰতকৈ বেলেগ Driver পঠোৱা।',
    r5: 'এনে sedan গাড়ী পঠোৱা য\'ত সঠিক বুট স্পেচ (ডিগি) বা carrier নাই। CNG গাড়ীত এনে হ\'ব পাৰে — CNG ছেডানৰ বুটত লগোৱা থাকিলে সামগ্ৰীৰ বাবে ঠাই থাকিব লাগিব।',
    r6: 'গাড়ীখন পৰিষ্কাৰ নাছিল।',
    r7: 'গাড়ীখন ভাল condition ত নাছিল।',
    r8: 'ড্ৰাইভাৰে দুৰ্ব্যৱহাৰ কৰিলে।',
  ),
};
