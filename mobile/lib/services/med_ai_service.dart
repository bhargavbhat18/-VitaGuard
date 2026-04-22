/// MedAI Service — Rule-based medication recommendation engine.
/// Works fully offline; no API key required.
library;

import 'package:vitalguard/models/vitals_model.dart';

class MedAiMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final List<String> suggestions;

  MedAiMessage({
    required this.text,
    required this.isUser,
    this.suggestions = const [],
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class MedAiService {
  VitalsModel? vitals;
  MedAiService({this.vitals});

  MedAiMessage respond(String userMessage) {
    final q = userMessage.toLowerCase().trim();

    if (_m(q, ['hello','hey','start','help']) || q == 'hi') {
      return _r(
        '👋 Hello! I\'m VitalGuard MedAI — your personal medication assistant.\n\n'
        'I can help you with:\n'
        '• Medication recommendations based on your vitals\n'
        '• What to take for high/low blood sugar\n'
        '• Heart, blood pressure & oxygen advice\n'
        '• Drug interaction warnings\n'
        '• When to see a doctor\n\n'
        'What can I help you with today?',
        ['Check my vitals', 'High blood sugar', 'Low oxygen', 'Heart rate high'],
      );
    }

    if (_m(q, ['my vitals','check vitals','current vitals','vitals','status'])) {
      return _vitalsReport();
    }

    // ── Glucose ────────────────────────────────────────────────
    if (_m(q, ['high blood sugar','high glucose','hyperglycemia','sugar is high','glucose high','elevated sugar'])) {
      return _r(
        '🩸 **High Blood Sugar (Hyperglycemia)**\n\n'
        '${_glucoseNote()}'
        '**Immediate steps:**\n'
        '1. Take your prescribed insulin as directed\n'
        '2. Drink plenty of water\n'
        '3. Avoid carbohydrates & sugary foods\n'
        '4. Light walk (10–15 min) if you feel well enough\n\n'
        '**Common medications:**\n'
        '• Metformin 500–1000 mg (with meals)\n'
        '• Rapid-acting insulin (Novorapid, Humalog)\n'
        '• Glipizide / Glibenclamide for Type 2\n\n'
        '⚠️ If glucose > 250 mg/dL or you feel nauseous/dizzy, seek emergency care.',
        ['Low blood sugar','Safe glucose range','Insulin types','When to see doctor'],
      );
    }

    if (_m(q, ['low blood sugar','low glucose','hypoglycemia','sugar is low','glucose low','feeling shaky'])) {
      return _r(
        '🍬 **Low Blood Sugar (Hypoglycemia)**\n\n'
        '${_glucoseNote()}'
        '**Immediate steps — Rule of 15:**\n'
        '1. Take 15g of fast-acting sugar immediately:\n'
        '   • 4 glucose tablets, OR\n'
        '   • 150 ml fruit juice, OR\n'
        '   • 3 tsp sugar in water\n'
        '2. Wait 15 minutes, recheck\n'
        '3. If still low, repeat step 1\n'
        '4. Once normal, eat a small meal\n\n'
        '🚨 If unconscious or unable to swallow, call emergency services immediately.',
        ['High blood sugar','Safe glucose range','Emergency'],
      );
    }

    if (_m(q, ['safe glucose','normal sugar','target glucose','blood sugar range'])) {
      return _r(
        '📊 **Safe Blood Glucose Ranges:**\n\n'
        '| Time | Target |\n|---|---|\n'
        '| Fasting | 70–100 mg/dL |\n'
        '| Before meals | 70–130 mg/dL |\n'
        '| 2h after meals | < 180 mg/dL |\n'
        '| Bedtime | 100–140 mg/dL |\n\n'
        '${_glucoseNote()}'
        'HbA1c target: **< 7%**',
        ['High blood sugar','Low blood sugar','Check my vitals'],
      );
    }

    // ── Blood Pressure ─────────────────────────────────────────
    if (_m(q, ['high blood pressure','high bp','hypertension','bp high','bp elevated','pressure high'])) {
      return _r(
        '❤️ **High Blood Pressure (Hypertension)**\n\n'
        '${_bpNote()}'
        '**Immediate steps:**\n'
        '1. Sit or lie down and rest for 5 minutes\n'
        '2. Take your prescribed antihypertensive if due\n'
        '3. Avoid salt, caffeine, and stress\n'
        '4. Slow, deep breathing for 5 minutes\n\n'
        '**Common medications:**\n'
        '• Amlodipine 5–10 mg (CCB)\n'
        '• Losartan 50–100 mg (ARB)\n'
        '• Atenolol 25–50 mg (Beta-blocker)\n'
        '• Hydrochlorothiazide 12.5 mg (Diuretic)\n\n'
        '🚨 BP > 180/120 mmHg → go to ER immediately.',
        ['Low blood pressure','Safe BP range','Beta blockers','Check my vitals'],
      );
    }

    if (_m(q, ['low blood pressure','low bp','hypotension','bp low','feeling dizzy','dizziness'])) {
      return _r(
        '💧 **Low Blood Pressure (Hypotension)**\n\n'
        '**Immediate steps:**\n'
        '1. Lie down and elevate legs 30 cm\n'
        '2. Drink water or an electrolyte drink\n'
        '3. Eat something salty\n'
        '4. Rise slowly from sitting/lying\n\n'
        '**Medications:**\n'
        '• Fludrocortisone (chronic hypotension)\n'
        '• Midodrine (narrowing blood vessels)\n\n'
        '⚠️ BP < 90/60 + confusion/fainting → call emergency services.',
        ['High blood pressure','Safe BP range','Check my vitals'],
      );
    }

    if (_m(q, ['safe bp','normal bp','blood pressure range','target bp'])) {
      return _r(
        '📊 **Blood Pressure Categories:**\n\n'
        '| Category | Systolic | Diastolic |\n|---|---|---|\n'
        '| Normal | < 120 | < 80 |\n'
        '| Elevated | 120–129 | < 80 |\n'
        '| Stage 1 HTN | 130–139 | 80–89 |\n'
        '| Stage 2 HTN | ≥ 140 | ≥ 90 |\n'
        '| Crisis | > 180 | > 120 |\n\n'
        '${_bpNote()}VitalGuard alert: **≥ 140/90 mmHg**',
        ['High blood pressure','Check my vitals'],
      );
    }

    // ── Heart Rate ─────────────────────────────────────────────
    if (_m(q, ['high heart rate','tachycardia','heart rate high','fast heart','hr high','heart beating fast','palpitations'])) {
      return _r(
        '💓 **High Heart Rate (Tachycardia)**\n\n'
        '${_hrNote()}'
        '**Immediate steps:**\n'
        '1. Sit down and rest immediately\n'
        '2. Try Valsalva maneuver: breathe in, bear down\n'
        '3. Splash cold water on your face\n'
        '4. Avoid caffeine & stimulants\n\n'
        '**Medications:**\n'
        '• Metoprolol 25–50 mg (beta-blocker)\n'
        '• Atenolol 25 mg\n'
        '• Diltiazem / Verapamil (CCB)\n\n'
        '🚨 HR > 150 bpm + chest pain → call emergency services.',
        ['Low heart rate','Safe heart rate','Beta blockers','Check my vitals'],
      );
    }

    if (_m(q, ['low heart rate','bradycardia','heart rate low','slow heart','hr low'])) {
      return _r(
        '💔 **Low Heart Rate (Bradycardia)**\n\n'
        '${_hrNote()}'
        '**Common causes:** Beta-blockers, hypothyroidism, athlete heart\n\n'
        '**Management:**\n'
        '• Asymptomatic ~40–50 bpm in athletes: often normal\n'
        '• Atropine (emergency IV use)\n'
        '• Pacemaker (severe cases)\n\n'
        '⚠️ HR < 40 bpm + fainting/chest pain → ER immediately.',
        ['Safe heart rate','Check my vitals'],
      );
    }

    if (_m(q, ['safe heart rate','normal heart rate','resting hr','heart rate range'])) {
      return _r(
        '📊 **Heart Rate Reference:**\n\n'
        '| Category | Range |\n|---|---|\n'
        '| Normal adult resting | 60–100 bpm |\n'
        '| Athletic resting | 40–60 bpm |\n'
        '| VitalGuard alert | 50–110 bpm |\n'
        '| Tachycardia | > 100 bpm |\n'
        '| Bradycardia | < 60 bpm |\n\n'
        '${_hrNote()}',
        ['High heart rate','Low heart rate','Check my vitals'],
      );
    }

    // ── SpO2 ───────────────────────────────────────────────────
    if (_m(q, ['low oxygen','low spo2','spo2 low','oxygen saturation','breathing difficulty','shortness of breath','inhaler','can\'t breathe'])) {
      return _r(
        '🌬️ **Low Oxygen Saturation (SpO2)**\n\n'
        '${_spo2Note()}'
        '**Immediate steps:**\n'
        '1. Sit upright — do not lie flat\n'
        '2. Use your prescribed inhaler (2 puffs)\n'
        '3. Pursed lip breathing: inhale 2 sec, exhale 4 sec\n'
        '4. Open windows for fresh air\n\n'
        '**Medications:**\n'
        '• Salbutamol (Ventolin) — rescue bronchodilator\n'
        '• Ipratropium (Atrovent) — COPD controller\n'
        '• Prednisolone 30–40 mg — asthma flare-up\n\n'
        '🚨 SpO2 < 90% or severe breathlessness → call 108 NOW.',
        ['Safe SpO2 range','Inhaler technique','Check my vitals'],
      );
    }

    if (_m(q, ['safe spo2','normal spo2','normal oxygen','spo2 range'])) {
      return _r(
        '📊 **SpO2 Reference:**\n\n'
        '| Level | SpO2 | Action |\n|---|---|---|\n'
        '| Normal | 95–100% | All good |\n'
        '| Mild hypoxia | 91–94% | Monitor closely |\n'
        '| VitalGuard alert | < 92% | Use inhaler |\n'
        '| Moderate | 86–90% | Seek medical help |\n'
        '| Severe | < 85% | Emergency — call 108 |\n\n'
        '${_spo2Note()}',
        ['Low oxygen','Check my vitals'],
      );
    }

    // ── Beta blockers ──────────────────────────────────────────
    if (_m(q, ['beta blocker','beta blockers','metoprolol','atenolol','bisoprolol','propranolol'])) {
      return _r(
        '💊 **Beta-Blockers — Overview**\n\n'
        '**What they do:** Slow heart rate, lower BP, reduce heart workload.\n\n'
        '**Common ones:**\n'
        '• Metoprolol succinate — 25–200 mg once daily\n'
        '• Atenolol — 25–50 mg once daily\n'
        '• Bisoprolol — 2.5–10 mg once daily\n'
        '• Propranolol — 40–80 mg twice daily\n\n'
        '**Used for:** Hypertension, tachycardia, angina, heart failure\n\n'
        '⚠️ Never stop beta-blockers suddenly — taper with doctor guidance.',
        ['High heart rate','High blood pressure','Drug interactions'],
      );
    }

    // ── Drug interactions ──────────────────────────────────────
    if (_m(q, ['interaction','interactions','drug interaction','drug interactions','combine','mixing medications','can i take'])) {
      return _r(
        '⚠️ **Common Drug Interaction Warnings:**\n\n'
        '❌ **Avoid combining:**\n'
        '• Metformin + contrast dye → kidney risk\n'
        '• Warfarin + Aspirin → increased bleeding\n'
        '• ACE inhibitors + Potassium → high potassium\n'
        '• Beta-blockers + CCBs → dangerous HR drop\n'
        '• Statins + Grapefruit juice → statin toxicity\n\n'
        '✅ **Generally safe together:**\n'
        '• Metformin + Amlodipine\n'
        '• Aspirin + Statin (if prescribed)\n\n'
        '💡 Always tell your pharmacist ALL medications including supplements.',
        ['Beta blockers','When to see doctor'],
      );
    }

    // ── When to see doctor ─────────────────────────────────────
    if (_m(q, ['doctor','when to see','emergency','hospital','serious','should i go'])) {
      return _r(
        '🏥 **When to Seek Medical Help:**\n\n'
        '🚨 **Call emergency (108) immediately if:**\n'
        '• Chest pain or pressure\n'
        '• SpO2 < 90% or severe breathlessness\n'
        '• BP > 180/120 (hypertensive crisis)\n'
        '• HR > 150 bpm with symptoms\n'
        '• Glucose < 50 mg/dL with confusion\n'
        '• Fainting or loss of consciousness\n\n'
        '⚠️ **See doctor within 24 hours if:**\n'
        '• BP consistently > 140/90 for 3+ days\n'
        '• Glucose > 250 mg/dL\n'
        '• New symptoms from medications',
        ['Check my vitals','Drug interactions'],
      );
    }

    // ── Insulin types ──────────────────────────────────────────
    if (_m(q, ['insulin','insulin types','rapid insulin','long acting insulin'])) {
      return _r(
        '💉 **Insulin Types:**\n\n'
        '| Type | Onset | Peak | Duration |\n|---|---|---|---|\n'
        '| Rapid (Novorapid) | 10–20 min | 1–3h | 3–5h |\n'
        '| Short (Regular) | 30–60 min | 2–4h | 5–8h |\n'
        '| Intermediate (NPH) | 1–2h | 4–10h | 10–16h |\n'
        '| Long (Lantus) | 1–2h | Flat | 20–24h |\n\n'
        '• Rapid-acting: take just before meals\n'
        '• Long-acting: same time every night\n'
        '• Rotate injection sites\n'
        '• Never share insulin pens',
        ['High blood sugar','Low blood sugar','Drug interactions'],
      );
    }

    // ── Inhaler technique ──────────────────────────────────────
    if (_m(q, ['inhaler technique','how to use inhaler','puffer','spacer'])) {
      return _r(
        '🫁 **Correct Inhaler Technique:**\n\n'
        '1. Shake inhaler well (5–6 times)\n'
        '2. Breathe out fully\n'
        '3. Place mouthpiece between lips\n'
        '4. Start breathing in slowly, press once\n'
        '5. Continue slow breath over 3–5 seconds\n'
        '6. Hold breath 10 seconds\n'
        '7. Breathe out slowly through nose\n'
        '8. Wait 1 minute before second puff\n\n'
        '💡 Use a **spacer** if coordination is difficult.\n'
        '**Rescue (Salbutamol):** Up to 4 puffs during attack\n'
        '**Steroid inhaler:** Rinse mouth after use',
        ['Low oxygen','Safe SpO2 range'],
      );
    }

    // ── Vitals-aware fallback ──────────────────────────────────
    if (vitals != null) return _vitalsContextual(q);

    return _r(
      '🤔 I didn\'t quite understand that. Try asking:\n\n'
      '• "What do I take for high blood pressure?"\n'
      '• "My oxygen is low, what should I do?"\n'
      '• "Insulin types"\n'
      '• "Drug interactions"\n'
      '• "When to see a doctor"',
      ['Check my vitals','High blood sugar','Low oxygen','High heart rate','Drug interactions'],
    );
  }

  MedAiMessage _vitalsContextual(String q) {
    final issues = <String>[];
    if (vitals!.glucose > 180)    issues.add('• Consider insulin — glucose is ${vitals!.glucose.toStringAsFixed(0)} mg/dL');
    if (vitals!.glucose < 70)     issues.add('• 🚨 Glucose critically low (${vitals!.glucose.toStringAsFixed(0)} mg/dL) — take sugar NOW');
    if (vitals!.spo2 < 92)        issues.add('• Use rescue inhaler — SpO2 is ${vitals!.spo2.toStringAsFixed(1)}%');
    if (vitals!.bpSystolic > 140) issues.add('• Rest + BP medication — BP is ${vitals!.bpSystolic.toStringAsFixed(0)}/${vitals!.bpDiastolic.toStringAsFixed(0)} mmHg');
    if (vitals!.heartRate > 110)  issues.add('• Rest + beta-blocker — HR is ${vitals!.heartRate.toStringAsFixed(0)} bpm');
    if (issues.isEmpty) {
      return _r(
        '✅ Your current vitals look normal. No medication actions needed right now.\n\n'
        'Ask me about any medication or condition!',
        ['High blood sugar','High blood pressure','Low oxygen','Drug interactions'],
      );
    }
    return _r(
      '⚠️ Based on your current vitals:\n\n${issues.join('\n\n')}\n\n'
      'Tap a suggestion for detailed guidance.',
      ['High blood sugar','High blood pressure','Low oxygen','High heart rate'],
    );
  }

  MedAiMessage _vitalsReport() {
    if (vitals == null) {
      return _r(
        '📡 No vitals data received yet. Make sure the simulator is running.\n\n'
        'Once data streams in, I can give personalised advice!',
        ['High blood sugar','High blood pressure','Low oxygen'],
      );
    }
    final issues = <String>[];
    if (vitals!.glucose > 180)    issues.add('🔴 Glucose high — consider insulin');
    if (vitals!.glucose < 70)     issues.add('🔴 Glucose critical low — sugar needed NOW');
    if (vitals!.spo2 < 92)        issues.add('🔴 SpO2 low — use inhaler');
    if (vitals!.bpSystolic > 140) issues.add('🟠 BP elevated — rest & BP medication');
    if (vitals!.heartRate > 110)  issues.add('🟠 HR elevated — rest & beta-blocker');
    final status = issues.isEmpty ? '✅ All vitals within safe range' : issues.join('\n');
    return _r(
      '📊 **Your Current Vitals:**\n\n'
      '❤️ Heart Rate: **${vitals!.heartRate.toStringAsFixed(0)} bpm**\n'
      '🩸 Glucose: **${vitals!.glucose.toStringAsFixed(0)} mg/dL**\n'
      '💨 SpO2: **${vitals!.spo2.toStringAsFixed(1)}%**\n'
      '🩺 BP: **${vitals!.bpSystolic.toStringAsFixed(0)}/${vitals!.bpDiastolic.toStringAsFixed(0)} mmHg**\n\n'
      '**Status:**\n$status',
      issues.isEmpty
        ? ['Drug interactions','Safe glucose range','Safe BP range']
        : ['High blood sugar','High blood pressure','Low oxygen','High heart rate'],
    );
  }

  String _glucoseNote() => vitals == null ? '' : '📱 *Current: ${vitals!.glucose.toStringAsFixed(0)} mg/dL*\n\n';
  String _bpNote()      => vitals == null ? '' : '📱 *Current: ${vitals!.bpSystolic.toStringAsFixed(0)}/${vitals!.bpDiastolic.toStringAsFixed(0)} mmHg*\n\n';
  String _hrNote()      => vitals == null ? '' : '📱 *Current: ${vitals!.heartRate.toStringAsFixed(0)} bpm*\n\n';
  String _spo2Note()    => vitals == null ? '' : '📱 *Current: ${vitals!.spo2.toStringAsFixed(1)}%*\n\n';

  /// Word-boundary match: pads both query and keyword with spaces so
  /// 'hi' cannot match inside 'high', 'interaction' cannot match inside 'interactions', etc.
  bool _m(String q, List<String> kw) {
    final padded = ' $q ';
    return kw.any((k) => padded.contains(' $k ') || padded.contains(' $k,') || padded.contains(' ${k}s '));
  }
  MedAiMessage _r(String text, [List<String> s = const []]) =>
      MedAiMessage(text: text, isUser: false, suggestions: s);

  static List<String> get starterSuggestions => [
    'Check my vitals', 'High blood sugar', 'High blood pressure',
    'Low oxygen', 'High heart rate', 'Drug interactions',
    'When to see doctor', 'Insulin types',
  ];
}
