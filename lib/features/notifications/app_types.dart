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

const Map<int, String> _iconNames = {
  MsgType.qq: 'QQ',
  MsgType.wechat: 'WeChat',
  MsgType.sms: 'SMS',
  MsgType.facebook: 'Facebook',
  MsgType.twitter: 'X / Twitter',
  MsgType.whatsapp: 'WhatsApp',
  MsgType.skype: 'Skype',
  MsgType.messenger: 'Messenger',
  MsgType.line: 'LINE',
  MsgType.linkedin: 'LinkedIn',
  MsgType.instagram: 'Instagram',
  MsgType.viber: 'Viber',
  MsgType.snapchat: 'Snapchat',
  MsgType.gmail: 'Gmail',
  MsgType.youtube: 'YouTube',
  MsgType.telegram: 'Telegram',
};

/// e.g. "WhatsApp icon on watch" / "Generic icon on watch".
String watchIconLabel(String package) {
  final name = _iconNames[msgTypeFor(package)];
  return name == null ? 'Generic icon on watch' : '$name icon on watch';
}

const Set<int> _messaging = {
  MsgType.qq, MsgType.wechat, MsgType.sms, MsgType.whatsapp, MsgType.skype, MsgType.messenger,
  MsgType.line, MsgType.viber, MsgType.snapchat, MsgType.telegram,
};

/// Chat / SMS apps the watch has a dedicated icon for ("Messaging" filter).
bool isMessagingApp(String package) => _messaging.contains(msgTypeFor(package));
