/// سجل أخطاء بدء التشغيل. يُعرض على شاشة الخطأ داخل التطبيق بدل أن يضيع
/// في سجلات النظام فقط، لأن التطبيق قد لا يكون موصولًا بـ `flutter logs`.
final List<String> bootLog = <String>[];

/// يضيف رسالة دون تكرار، ويحافظ على آخر 40 رسالة فقط.
void logBoot(String message) {
  if (bootLog.contains(message)) return;
  bootLog.add(message);
  if (bootLog.length > 40) bootLog.removeAt(0);
}
