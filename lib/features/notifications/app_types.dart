import '../../protocol/commands.dart';

/// Which icon the watch shows for an app. Unknown apps use "other".
const Map<String, int> _byPackage = {
  'com.whatsapp': MsgType.whatsapp,
  'com.whatsapp.w4b': MsgType.whatsapp,
  'org.telegram.messenger': MsgType.telegram,
  'org.thunderdog.challegram': MsgType.telegram,
  'com.facebook.katana': MsgType.facebook,
  'com.facebook.lite': MsgType.facebook,
  'com.facebook.orca': MsgType.messenger,
  'com.facebook.mlite': MsgType.messenger,
  'com.instagram.android': MsgType.instagram,
  'com.twitter.android': MsgType.twitter,
  'com.google.android.gm': MsgType.gmail,
  'com.google.android.youtube': MsgType.youtube,
  'com.linkedin.android': MsgType.linkedin,
  'com.snapchat.android': MsgType.snapchat,
  'com.viber.voip': MsgType.viber,
  'com.skype.raider': MsgType.skype,
  'jp.naver.line.android': MsgType.line,
  'com.tencent.mm': MsgType.wechat,
  'com.tencent.mobileqq': MsgType.qq,
  'com.google.android.apps.messaging': MsgType.sms,
  'com.android.mms': MsgType.sms,
  'com.samsung.android.messaging': MsgType.sms,
  'com.transsion.messaging': MsgType.sms, // Infinix / Tecno
};

int msgTypeFor(String package) => _byPackage[package] ?? MsgType.other;
