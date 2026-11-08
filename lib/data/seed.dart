
```dart
import 'models.dart';

DateTime nextWorkday(DateTime d) {
  var x = dateOnly(d);
  while (x.weekday == DateTime.friday || x.weekday == DateTime.saturday) {
    x = DateTime(x.year, x.month, x.day + 1);
  }
  return x;
}

/// 20 أيام دوام (الأحد–الخميس) ابتداءً من [start]
List<Task> missionFrom(DateTime start) {
  var day = nextWorkday(start);
  final now = DateTime.now();
  final out = <Task>[];
  for (final m in _mission) {
    out.add(Task(
      titleEn: m[0],
      titleAr: m[1],
      detailsEn: m[2],
      detailsAr: m[3],
      category: m[4],
      date: day,
      isMission: true,
      updatedAt: now,
    ));
    day = nextWorkday(DateTime(day.year, day.month, day.day + 1));
  }
  return out;
}

/// [enTitle, arTitle, enDetails, arDetails, category]
const _mission = <List<String>>[
  [
    'Day 1: Onboarding, Access Creds & Child Safeguarding',
    'اليوم 1: المباشرة، الصلاحيات وتدقيق حماية الطفل',
    'From: HR (signed JD, badge ID, staff handbook) & IT (SOS mail, work phone/SIM).\nDo: Set up workspace storage folders, enable 2FA on SOS cloud, study the SOS Child Safeguarding Policy.\nContact: Area Director / Line Manager on immediate Mawasi camp protection concerns.',
    'من: الموارد البشرية (الوصف الوظيفي، بطاقة العمل، دليل الموظف) وتكنولوجيا المعلومات (بريد SOS، هاتف العمل، الشريحة).\nالتنفيذ: تهيئة مجلدات العمل، تفعيل التحقق الثنائي على الحساب السحابي، ودراسة سياسة حماية وصون الطفل.\nالتنسيق: مدير المنطقة / المدير المباشر لتحديد أولويات حماية مخيم المواصي الفورية.',
    'admin',
  ],
  [
    'Day 2: Mawasi Camp Layout & UASC Custody Files',
    'اليوم 2: حصر ملفات مخيم المواصي وقوائم الأطفال الأيتام',
    'From: Programs (camp layout, orphan headcount, night caregiver roster).\nDo: Verify the emergency contact list and check tent allocation for unaccompanied children (UASC).\nContact: Child Protection Specialist on family tracing risks and custody attempts.',
    'من: إدارة البرامج (مخطط المخيم، كشف الأيتام، جدول المربيات الليلي).\nالتنفيذ: تدقيق أرقام الطوارئ ومطابقة خيام مبيت الأطفال غير المصحوبين (UASC).\nالتنسيق: أخصائي حماية الطفل حول مخاطر التتبع العائلي ومحاولات استرداد الأطفال.',
    'child',
  ],
  [
    'Day 3: Incident Log Pipeline & SRT Integration',
    'اليوم 3: تأسيس سجل الحوادث والاندماج في فريق الأزمات',
    'From: Operations Director: access to crisis channels (SRT/SLT).\nDo: Deploy the Master Security Incident Tracker with geocodes for Khan Yunis.\nContact: Security Response Team (SRT): agree on the daily morning briefing at 08:30.',
    'من: مدير العمليات: صلاحية الانضمام لقنوات فريق الأزمات (SRT/SLT).\nالتنفيذ: بناء سجل الحوادث الموحد لتوثيق أي خرق أو تهديد لمخيم المواصي.\nالتنسيق: فريق الاستجابة للأزمات: الاتفاق على الإحاطة الصباحية 08:30.',
    'security',
  ],
  [
    'Day 4: External Security Coordination (INSO, UNDSS, Peers)',
    'اليوم 4: التنسيق الأمني الخارجي (INSO، UNDSS والمنظمات القريبة)',
    'From: Line Manager: official credential letter for INSO / UNDSS security networks.\nDo: Register with INSO Gaza for flash SMS alerts, map alerts and security briefings.\nContact: Peer security officers in neighbouring Mawasi camps and field clinics.',
    'من: المدير المباشر: خطاب تفويض لعضوية شبكات INSO / UNDSS.\nالتنفيذ: التسجيل لدى INSO غزة للتنبيهات الفورية والخرائط والإحاطات الأمنية.\nالتنسيق: مسؤولو الأمن في المنظمات والعيادات الميدانية المجاورة بالمواصي.',
    'security',
  ],
  [
    'Day 5: Week 1 Synthesis & Camp Audit Checklist Prep',
    'اليوم 5: تقرير نهاية الأسبوع الأول وتجهيز قوائم التدقيق',
    'From: Logistics: vehicle and inspection tools for next week\'s physical audits.\nDo: Draft the Mawasi Child-Camp Security Checklist (perimeter, power, fire, lighting, safe tents).\nContact: Mawasi Camp Manager to confirm the inspection timetable.',
    'من: اللوجستيات: سيارة ومعدات الفحص الميداني لجولات الأسبوع الثاني.\nالتنفيذ: إعداد قائمة فحص السلامة لمخيم أطفال المواصي (الأسوار، الكهرباء، الحرائق، الإضاءة، الخيام الآمنة).\nالتنسيق: مدير مخيم المواصي لتأكيد موعد الجولة التفتيشية.',
    'logistics',
  ],
  [
    'Day 6: Mawasi Perimeter & Anti-Intrusion Night Audit',
    'اليوم 6: فحص السياج الخارجي وبوابات مخيم المواصي',
    'From: Camp Manager & Head Guard: access to perimeter, gates and visitor logs.\nDo: Inspect fence integrity, entry locks and solar floodlights; enforce the ZERO WEAPONS POLICY at gates.\nContact: Guard force: strict visitor vetting and full lockdown after 17:30.',
    'من: مدير المخيم ومسؤول الحراسة: فتح محيط المخيم والبوابات وسجلات الزوار.\nالتنفيذ: فحص متانة الأسوار والأقفال والكشافات الشمسية، وتطبيق سياسة صفر أسلحة عند البوابات.\nالتنسيق: طاقم الحراسة: تدقيق الزوار بصرامة وإغلاق كامل بعد 17:30.',
    'security',
  ],
  [
    'Day 7: Children Tent Electrical & Structural Hazard Check',
    'اليوم 7: فحص تمديدات خيام الأطفال ومخاطر الصعق الكهربائي',
    'From: Head Caregiver: full access to residential tents and caravans housing orphaned children.\nDo: Check solar inverter lines, isolate exposed wiring, clear tent guy ropes from paths.\nContact: Foster mothers & caregivers: listen to night safety concerns and cold/rain leaks.',
    'من: المشرفة المقيمة: مرافقة كاملة لممرات وخيام إيواء الأيتام.\nالتنفيذ: فحص خطوط العاكس الشمسي، عزل الأسلاك المكشوفة، وإزالة حبال الخيام من الممرات.\nالتنسيق: الأمهات البديلات والمربيات: الاستماع لملاحظاتهن حول الأمان الليلي والتسربات.',
    'child',
  ],
  [
    'Day 8: Fire Extinguishers & Fuel/LPG Storage Audit',
    'اليوم 8: فحص طفايات الحريق وأسطوانات الغاز والمطبخ',
    'From: Logistics & Camp Cook: access to kitchen LPG cylinders, burners and safety gear.\nDo: Inspect dry-powder extinguishers and pressure gauges; test wet-sand fire buckets.\nContact: Kitchen staff: enforce a child-free perimeter around cooking and gas areas.',
    'من: اللوجستيات وطباخ المخيم: فحص أسطوانات الغاز والمواقد ومعدات الأمان.\nالتنفيذ: فحص طفايات البودرة وضغطها، وتجهيز براميل الرمل الرطب.\nالتنسيق: طاقم المطبخ: منع اقتراب الأطفال تماماً من منطقة الطهي والأسطوانات.',
    'logistics',
  ],
  [
    'Day 9: Fleet Vehicle & Evacuation Medical Kits',
    'اليوم 9: تدقيق مركبات الحركة وحقائب الإسعاف والطوارئ',
    'From: Fleet Supervisor: maintenance logs, driver licences and in-car safety kits.\nDo: Audit spare tyres (sand-terrain readiness), tow ropes, first-aid kits and chargers.\nContact: Drivers: brief on approved medical evacuation routes to the nearest field clinic.',
    'من: مسؤول الأسطول: سجلات الصيانة ورخص السائقين وحقائب السلامة داخل السيارات.\nالتنفيذ: فحص الإطارات الاحتياطية (جاهزية رمال المواصي)، أحزمة السحب، حقائب الإسعاف، والشواحن.\nالتنسيق: السائقون: مراجعة خطوط الإخلاء الطبي المعتمدة لأقرب عيادة ميدانية.',
    'logistics',
  ],
  [
    'Day 10: Findings Matrix & Urgent Safety Procurement',
    'اليوم 10: مصفوفة الثغرات وطلبات الشراء والصيانة العاجلة',
    'From: Procurement / Logistics: priority quotes for urgent safety equipment.\nDo: Consolidate the Security Findings Matrix; issue purchase requests for missing extinguishers and solar lights.\nContact: Area Director: approve emergency purchase requisitions and the repair budget.',
    'من: المشتريات / اللوجستيات: عروض أسعار عاجلة لمعدات السلامة.\nالتنفيذ: تفريغ مصفوفة الثغرات وإصدار طلبات شراء للطفايات والكشافات الشمسية الناقصة.\nالتنسيق: مدير المنطقة: اعتماد طلبات الشراء العاجلة وموازنة الإصلاح.',
    'logistics',
  ],
  [
    'Day 11: Movement Clearance & Check-in Automation',
    'اليوم 11: أتمتة تصاريح الحركة ونظام التحقق الرقمي',
    'From: Program Managers: weekly movement schedule for child-care field staff.\nDo: Deploy a standard Movement Clearance Form with mandatory check-in points (departure, arrival, return).\nContact: Field teams & drivers: train on the check-in message protocol.',
    'من: مدراء المشاريع: جدول التحركات الأسبوعي لفرق رعاية الأطفال.\nالتنفيذ: تفعيل نموذج تصريح الحركة الموحد مع نقاط تحقق إلزامية (المغادرة، الوصول، العودة).\nالتنسيق: الفرق الميدانية والسائقون: التدريب على بروتوكول رسائل التحقق.',
    'security',
  ],
  [
    'Day 12: Emergency Cascading Phone Tree Restructure',
    'اليوم 12: إعادة هيكلة شجرة الاتصال للطوارئ',
    'From: HR & Mawasi Site Supervisor: 100% updated mobile numbers and alternate SIMs.\nDo: Build the hierarchical phone tree: Security Officer → Site Leads → Caregivers & Guards, so any alert reaches everyone within 5 minutes.\nContact: Tree focal points: confirm their role in relaying alerts and confirming receipt.',
    'من: الموارد البشرية ومشرف الموقع: أرقام محدثة 100% وشرائح بديلة.\nالتنفيذ: بناء شجرة الاتصال الهرمية: مسؤول الأمن ← قادة المواقع ← المربيات والحراس، بحيث يصل أي إنذار للجميع خلال 5 دقائق.\nالتنسيق: نقاط الاتصال المحورية: توضيح دورهم في تمرير البلاغ وتأكيد الاستلام.',
    'security',
  ],
  [
    'Day 13: Mawasi Transit Corridors & Medical Evac Mapping',
    'اليوم 13: مسارات التحرك الآمنة وخريطة النقاط الطبية',
    'From: INSO / UN GIS maps: road conditions and open access axes across Khan Yunis and the coastal road.\nDo: Map primary and alternate safe routes from Mawasi camp to Red Cross / UK-Med field clinics.\nContact: Logistics & drivers: distribute laminated pocket route maps with medical contacts.',
    'من: خرائط INSO / الأمم المتحدة: حالة الطرق والمحاور المفتوحة في خانيونس والطريق الساحلي.\nالتنفيذ: رسم المسارات الآمنة الأساسية والبديلة من المخيم إلى العيادات الميدانية للهلال الأحمر و UK-Med.\nالتنسيق: اللوجستيات والسائقون: توزيع خرائط مصغرة ومغلفة مع أرقام الطوارئ الطبية.',
    'logistics',
  ],
  [
    'Day 14: Telecom Blackout SOP & Non-Cellular Contingency',
    'اليوم 14: بروتوكول انقطاع الاتصالات والإنترنت التام',
    'From: Mawasi Site Supervisor: inventory of whistles, horns and solar flashlights.\nDo: Issue a written Blackout SOP: freeze inter-governorate movement and set fixed-window check-ins.\nContact: Area Director: approve the offline liaison-runner protocol and alternate meeting points.',
    'من: مشرف موقع المواصي: جرد الصافرات والأبواق والكشافات الشمسية.\nالتنفيذ: إصدار بروتوكول الانقطاع المكتوب: تجميد التنقل بين المحافظات، وتحديد أوقات فحص ثابتة.\nالتنسيق: مدير المنطقة: اعتماد بروتوكول المراسل اليدوي ونقاط الالتقاء البديلة.',
    'security',
  ],
  [
    'Day 15: Phone Tree Silent Cascade Test (Dry-Run)',
    'اليوم 15: اختبار تجريبي صامت لشجرة الاتصال',
    'From: Area Director: approval to send the drill message at 10:00.\nDo: Send "DRILL - CONFIRM RECEIPT". Track total minutes and dead nodes.\nContact: Staff who did not respond within 15 minutes: troubleshoot reception or update SIM numbers.',
    'من: مدير المنطقة: الموافقة على إرسال رسالة التمرين الساعة 10:00.\nالتنفيذ: إرسال "اختبار أمني تجريبي - يرجى تأكيد الاستلام"، وقياس الزمن الكلي والعقد المتعطلة.\nالتنسيق: الموظفون الذين لم يستجيبوا خلال 15 دقيقة: فحص الاستقبال أو تحديث أرقام الشرائح.',
    'security',
  ],
  [
    'Day 16: Caregiver Security & Trauma-Informed Briefing',
    'اليوم 16: ورشة توعية أمنية للأمهات البديلات والمربيات',
    'From: Camp Supervisor: 1-hour relief coverage for foster mothers, in two batches.\nDo: Run a practical session: calm shelter-in-place, staying away from outer tent canvas.\nContact: Foster mothers: practical calming techniques to prevent child panic.',
    'من: مشرف المخيم: تغطية بديلة لساعة للأمهات البديلات على دفعتين.\nالتنفيذ: تدريب عملي: التمترس الهادئ، والابتعاد عن أطراف الخيام الخارجية.\nالتنسيق: الأمهات البديلات: تقنيات عملية لتهدئة الأطفال ومنع الهلع الجماعي.',
    'child',
  ],
  [
    'Day 17: Practical Fire Extinguisher Drill in Camp',
    'اليوم 17: تمرين عملي لمحاكاة إطفاء حريق في المخيم',
    'From: Camp Lead: a safe drill area away from children\'s sleeping quarters.\nDo: Run the simulation: whistle alarm → sand bucket → extinguisher discharge (PASS rule).\nContact: Guards and camp crew: debrief on reaction time and nozzle aim against the wind.',
    'من: مدير المخيم: منطقة تدريب آمنة بعيداً عن خيام نوم الأطفال.\nالتنفيذ: المحاكاة: إطلاق الإنذار ← براميل الرمل ← إطلاق الطفاية (قاعدة PASS).\nالتنسيق: الحراس وطاقم المخيم: تقييم زمن الاستجابة وتصويب الفوهة مع اتجاه الريح.',
    'security',
  ],
  [
    'Day 18: Child-Friendly Soft Shelter-in-Place Drill',
    'اليوم 18: محاكاة تمترس هادئة وصديقة للأطفال الأيتام',
    'From: Child Protection Lead & MHPSS team: supervision of the interactive activity.\nDo: Guide children calmly into the most reinforced communal tent without triggering alarm.\nContact: MHPSS specialists: review child reactions and address any signs of anxiety.',
    'من: مسؤول حماية الطفل وفريق الدعم النفسي (MHPSS): الإشراف على النشاط التفاعلي.\nالتنفيذ: توجيه الأطفال بهدوء إلى الخيمة الجماعية الأكثر تحصيناً دون إثارة الهلع.\nالتنسيق: أخصائيو الدعم النفسي: تقييم ردود أفعال الأطفال ومعالجة أي علامات قلق.',
    'child',
  ],
  [
    'Day 19: Month 1 Comprehensive Security Review Report',
    'اليوم 19: صياغة التقرير الأمني التقييمي الشامل للشهر الأول',
    'From: Logistics, Camp Manager & Maintenance: final status of resolved audit items.\nDo: Draft the first 30-day security evaluation covering Mawasi mitigations, remaining gaps and recommendations.\nContact: Area Director: present the executive summary and risk-reduction roadmap.',
    'من: اللوجستيات ومدير المخيم والصيانة: الحالة النهائية للبنود المعالجة.\nالتنفيذ: كتابة تقييم الأمن الشامل للشهر الأول، يوضح التحصينات والثغرات المتبقية والتوصيات.\nالتنسيق: مدير المنطقة: عرض الملخص التنفيذي وخارطة تقليل المخاطر.',
    'admin',
  ],
  [
    'Day 20: 90-Day Operational Plan & SSP Ratification',
    'اليوم 20: إقرار خطة العمل للأشهر الثلاثة القادمة (90 يوماً)',
    'From: Senior Leadership Team: final conference to approve the next safety roadmap.\nDo: Ratify the Mawasi Camp Site Security Plan (SSP) and schedule the monthly routine inspection calendar.\nContact: All operations & programme colleagues: transition to stable operations.',
    'من: فريق القيادة العليا: جلسة اعتماد مخرجات الشهر وخارطة الربع القادم.\nالتنفيذ: اعتماد خطة أمن موقع مخيم المواصي (SSP) وجدولة الفحص الدوري الشهري.\nالتنسيق: كافة زملاء العمليات والبرامج: الانتقال إلى وضع التشغيل المستقر.',
    'admin',
  ],
];
```
