/**
 * Health insight from vitals. Supports Google Gemini and OpenAI-style APIs.
 * Set LLM_PROVIDER=gemini and LLM_API_KEY=your_google_api_key for Gemini.
 * Supports language codes: 'en' (English), 'am' (Amharic), 'om' (Afaan Oromo).
 */

// ── Language-specific system prompts ────────────────────────────────────────

const SYSTEM_PROMPT_EN = `You are a health assistant. Given vital signs, reply with ONLY a valid JSON object (no markdown, no extra text):
{"summaryText":"2-3 sentence plain-language summary","riskLevel":"low|moderate|high|critical","conditionCategory":"e.g. normal, respiratory concern, obesity","preventiveAdvice":"1-2 sentences of advice"}

Use WHO norms: HR 60-100, SpO2 95-100%, Temp 36.1-37.2°C, BMI 18.5-24.9. This is NOT a diagnosis; do not replace a doctor.
If most values are N/A or only one vital was measured, say so in summaryText and suggest measuring more vitals; do not claim "all vital signs are within normal ranges" when most data is missing.
Important: Output must be valid JSON. Use only double quotes for strings; escape any quote inside a string with backslash (e.g. \\"). Keep summaryText and preventiveAdvice to 1-2 short sentences each.
Write summaryText and preventiveAdvice in English.`;

const SYSTEM_PROMPT_AM = `እርስዎ የጤና ረዳት ነዎት። የህይወት ምልክቶች ሲሰጡ፣ ONLY ትክክለኛ JSON ነገር ይመልሱ (markdown ወይም ተጨማሪ ጽሑፍ አይጨምሩ):
{"summaryText":"2-3 ዓረፍተ ነገር ቀላል ማጠቃለያ","riskLevel":"low|moderate|high|critical","conditionCategory":"ለምሳሌ normal, hypertension, respiratory concern, obesity","preventiveAdvice":"1-2 ዓረፍተ ነገር ምክር"}

የWHO ደረጃዎችን ይጠቀሙ: BP 90-120/60-80, HR 60-100, SpO2 95-100%, ሙቀት 36.1-37.2°C, BMI 18.5-24.9. ይህ ምርመራ አይደለም; ሐኪምን አይተካም።
አብዛኛዎቹ እሴቶች N/A ከሆኑ ወይም አንድ ብቻ ከተለካ፣ ይህን በsummaryText ይጥቀሱ እና ተጨማሪ ምልክቶችን እንዲለኩ ይጠቁሙ።
አስፈላጊ: ውጤቱ ትክክለኛ JSON መሆን አለበት። ለሕብረቁምፊዎች ድርብ ጥቅሶችን ብቻ ይጠቀሙ። summaryText እና preventiveAdvice አጭር ያድርጓቸው።
summaryText እና preventiveAdvice በአማርኛ ቋንቋ ይጻፉ።`;

const SYSTEM_PROMPT_OM = `Ati gargaaraa fayyaa dha. Mallattoolee jireenyaa yoo kenname, ONLY wantoota JSON sirrii ta'an deebisi (markdown ykn barruu dabalataa hin galchin):
{"summaryText":"Cuunfaa gababaa 2-3 jechoota","riskLevel":"low|moderate|high|critical","conditionCategory":"fkn. normal, hypertension, respiratory concern, obesity","preventiveAdvice":"Gorsa jechoota 1-2"}

Safartuu WHO fayyadami: BP 90-120/60-80, HR 60-100, SpO2 95-100%, Ho'a 36.1-37.2°C, BMI 18.5-24.9. Kun murtoo kilinikaa MITI; ogeessa fayyaa bakka hin bu'u.
Gatiin hedduu N/A yoo ta'e ykn tokko qofa yoo safartame, summaryText keessatti ibsi fi mallattoolee dabalataa safaruuf gorsii.
Barbaachisaa: Bu'aan JSON sirrii ta'uu qaba. Tarreewwan dachaa qofa fayyadami. summaryText fi preventiveAdvice gabaabaa ta'uu qabu.
summaryText fi preventiveAdvice Afaan Oromoo tiin barreessi.`;

function getSystemPrompt(language) {
  switch (language) {
    case 'am': return SYSTEM_PROMPT_AM;
    case 'om': return SYSTEM_PROMPT_OM;
    default:   return SYSTEM_PROMPT_EN;
  }
}

// ── Fallback strings per language ────────────────────────────────────────────

const FALLBACK_STRINGS = {
  en: {
    noMeasurements: 'No measurements to analyze. Complete at least one vital sign measurement for an AI health summary.',
    noMeasurementsAdvice: 'Use the kiosk to measure blood pressure, height, weight, SpO2, heart rate, or temperature, then request analysis again.',
    allNormal: 'All measured vital signs are within normal ranges.',
    detected: (issues) => `Detected: ${issues.join(', ')}. Please consult a healthcare professional for proper evaluation.`,
    llmFailed: (base, errMsg) => `AI analysis could not be completed. (${errMsg}) The following is a basic summary: ${base}`,
    normalAdvice: 'Continue maintaining a healthy lifestyle with regular exercise and balanced diet.',
    issueAdvice: 'Schedule a follow-up with a healthcare provider. Monitor your vitals regularly.',
  },
  am: {
    noMeasurements: 'ለመተንተን መለኪያ የለም። የAI ጤና ማጠቃለያ ለማግኘት ቢያንስ አንድ ህይወታዊ ምልክት ይለኩ።',
    noMeasurementsAdvice: 'የደም ግፊት፣ ቁመት፣ ክብደት፣ SpO2፣ የልብ ምት፣ ወይም ሙቀት ለመለካት ኪዮስኩን ይጠቀሙ፣ ከዚያ ትንተናን እንደገና ይጠይቁ።',
    allNormal: 'የተለኩ ሁሉም ህይወታዊ ምልክቶች በተለመደ ደረጃ ውስጥ ናቸው።',
    detected: (issues) => `የተገኘ: ${issues.join('፣ ')}። ለትክክለኛ ምርመራ እባክዎ የጤና ባለሙያ ያማክሩ።`,
    llmFailed: (base, errMsg) => `AI ትንተና ሊጠናቀቅ አልቻለም። (${errMsg}) የሚከተለው መሰረታዊ ማጠቃለያ ነው: ${base}`,
    normalAdvice: 'በመደበኛ ልምምድ እና ሚዛናዊ አመጋገብ ጤናማ የአኗኗር ዘይቤን ይቀጥሉ።',
    issueAdvice: 'ከጤና አቅራቢ ጋር ቀጠሮ ይያዙ። ህይወታዊ ምልክቶችዎን በመደበኛነት ይከታተሉ።',
  },
  om: {
    noMeasurements: 'Xiinxalamuuf safartuu hin jiru. Cuunfaa fayyaa AI argachuuf mallattoo jireenyaa tokko yoo xiqqaate safarti.',
    noMeasurementsAdvice: 'Dhiibbaa dhiigaa, dheerina, ulfaatina, SpO2, saffisa onnee, ykn ho\'a safaruuf kiyooskii fayyadami, itti aansuun xiinxala gaafadhu.',
    allNormal: 'Mallattooleen jireenyaa safaraman hundi daangaa idilee keessa jiru.',
    detected: (issues) => `Argame: ${issues.join(', ')}. Maaloo madaallii sirrii argachuuf ogeessa fayyaa mari\'adhu.`,
    llmFailed: (base, errMsg) => `Xiinxalli AI xumuramuu hin dandeenye. (${errMsg}) Cuunfaan bu\'uuraa itti aanaa: ${base}`,
    normalAdvice: 'Jireenya fayyaalessa ittifufi — shaakala dhaabbataa fi nyaata madaalawaa.',
    issueAdvice: 'Ogeessa fayyaa waliin beellama qabadhu. Mallattoolee jireenyaa kee yeroo yeroon hordofi.',
  },
};

// Issue labels per language (used in rule-based fallback)
const ISSUE_LABELS = {
  en: {
    elevatedBP: 'elevated blood pressure',
    lowSpo2: 'low oxygen saturation',
    elevatedHR: 'elevated heart rate',
    lowHR: 'low heart rate',
    elevatedTemp: 'elevated temperature',
    obesity: 'BMI indicates obesity',
  },
  am: {
    elevatedBP: 'ከፍ ያለ የደም ግፊት',
    lowSpo2: 'ዝቅተኛ የኦክሲጅን ሙሌት',
    elevatedHR: 'ከፍ ያለ የልብ ምት',
    lowHR: 'ዝቅተኛ የልብ ምት',
    elevatedTemp: 'ከፍ ያለ ሙቀት',
    obesity: 'BMI ውፍረትን ያሳያል',
  },
  om: {
    elevatedBP: 'dhiibbaa dhiigaa ol\'aanaa',
    lowSpo2: 'sadarkaa oksijiinii gadi aanaa',
    elevatedHR: 'saffisa onnee ol\'aanaa',
    lowHR: 'saffisa onnee gadi aanaa',
    elevatedTemp: 'ho\'a ol\'aanaa',
    obesity: 'BMI furdina agarsiisa',
  },
};

// ── Helpers ──────────────────────────────────────────────────────────────────

/** True if at least one vital was measured (weight 0 counts as not measured). */
function hasAnyVital(v) {
  if (!v || typeof v !== 'object') return false;
  if (v.systolicBP != null || v.diastolicBP != null) return true;
  if (v.heartRate != null || v.spo2 != null) return true;
  if (v.temperatureCelsius != null) return true;
  if (v.heightCm != null) return true;
  if (v.weightKg != null && v.weightKg !== 0) return true;
  if (v.bmi != null) return true;
  return false;
}

// ── Main entry point ─────────────────────────────────────────────────────────

async function analyzeVitals(vitals, patientHistory, language = 'en') {
  const lang = ['en', 'am', 'om'].includes(language) ? language : 'en';
  const provider = process.env.LLM_PROVIDER || (process.env.LLM_API_KEY?.startsWith('AIza') ? 'gemini' : 'openai');
  const apiKey = process.env.LLM_API_KEY;

  if (!hasAnyVital(vitals)) {
    console.log('[LLM] Skipping LLM: no vitals measured');
    return generateFallbackInsight(vitals, true, null, lang);
  }
  if (!apiKey || apiKey === 'your_llm_api_key') {
    console.log('[LLM] Skipping LLM: API key missing or placeholder');
    return generateFallbackInsight(vitals, false, null, lang);
  }

  console.log(`[LLM] Calling Gemini for analysis (lang=${lang})`);
  const userMessage = `Latest vitals:
Systolic/Diastolic BP: ${vitals.systolicBP ?? 'N/A'}/${vitals.diastolicBP ?? 'N/A'} mmHg
Heart Rate: ${vitals.heartRate ?? 'N/A'} bpm | SpO2: ${vitals.spo2 ?? 'N/A'}%
Temperature: ${vitals.temperatureCelsius ?? 'N/A'}°C | Weight: ${vitals.weightKg ?? 'N/A'} kg | Height: ${vitals.heightCm ?? 'N/A'} cm | BMI: ${vitals.bmi ?? 'N/A'}
${patientHistory?.length ? `Recent history: ${JSON.stringify(patientHistory)}` : ''}

Reply with only the JSON object.`;

  try {
    if (provider === 'gemini') {
      return await callGemini(apiKey, userMessage, lang);
    }
    return await callOpenAI(apiKey, userMessage, lang);
  } catch (err) {
    console.error('[LLM] API error, using fallback:', err.message);
    return generateFallbackInsight(vitals, false, err.message, lang);
  }
}

// ── Gemini / OpenAI callers ───────────────────────────────────────────────────

const GEMINI_DEFAULT_MODEL = 'gemini-2.5-flash';
const GEMINI_DEPRECATED_MODELS = ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-1.0-pro'];

function getGeminiModel() {
  const envModel = process.env.LLM_MODEL || GEMINI_DEFAULT_MODEL;
  if (GEMINI_DEPRECATED_MODELS.includes(envModel)) {
    console.log('[LLM] Model', envModel, 'is deprecated; using', GEMINI_DEFAULT_MODEL);
    return GEMINI_DEFAULT_MODEL;
  }
  return envModel;
}

async function callGemini(apiKey, userMessage, lang) {
  const model = getGeminiModel();
  const systemPrompt = getSystemPrompt(lang);
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: `${systemPrompt}\n\n${userMessage}` }] }],
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 1024,
      },
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini ${res.status}: ${errText}`);
  }
  const data = await res.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (text == null || String(text).trim() === '') {
    const finishReason = data.candidates?.[0]?.finishReason;
    const blockReason = finishReason && finishReason !== 'STOP' ? ` finishReason=${finishReason}` : '';
    const promptFeedback = data.promptFeedback ? ` promptFeedback=${JSON.stringify(data.promptFeedback)}` : '';
    console.error('[LLM] Gemini returned no text.', blockReason, promptFeedback);
    throw new Error(`No text in Gemini response${blockReason || promptFeedback || ' (empty or blocked)'}`);
  }
  try {
    return parseJsonInsight(String(text));
  } catch (e) {
    console.error('[LLM] Gemini JSON parse failed. Raw response (first 500 chars):', String(text).slice(0, 500));
    throw new Error(`Invalid JSON from Gemini: ${e.message}`);
  }
}

async function callOpenAI(apiKey, userMessage, lang) {
  const apiUrl = process.env.LLM_API_URL || 'https://api.openai.com/v1/chat/completions';
  const model = process.env.LLM_MODEL || 'gpt-4';
  const systemPrompt = getSystemPrompt(lang);
  const res = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userMessage },
      ],
      temperature: 0.3,
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`OpenAI ${res.status}: ${errText}`);
  }
  const data = await res.json();
  const text = data.choices?.[0]?.message?.content;
  if (!text) throw new Error('No content in OpenAI response');
  return parseJsonInsight(text);
}

// ── JSON parsing ──────────────────────────────────────────────────────────────

function parseJsonInsight(text) {
  if (text == null || typeof text !== 'string') throw new Error('Empty or invalid JSON');
  let cleaned = text.replace(/```json\s*|\s*```/g, '').trim();
  const firstBrace = cleaned.indexOf('{');
  if (firstBrace !== -1) {
    const lastBrace = cleaned.lastIndexOf('}');
    if (lastBrace > firstBrace) cleaned = cleaned.slice(firstBrace, lastBrace + 1);
  }
  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch (e) {
    parsed = parseJsonInsightFallback(cleaned);
    if (!parsed) throw e;
  }
  if (!parsed || typeof parsed !== 'object') throw new Error('Empty or invalid JSON');
  return {
    summaryText: String(parsed.summaryText ?? 'Summary not available.').trim() || 'Summary not available.',
    riskLevel: ['low', 'moderate', 'high', 'critical'].includes(parsed.riskLevel) ? parsed.riskLevel : 'low',
    conditionCategory: String(parsed.conditionCategory ?? 'normal').trim() || 'normal',
    preventiveAdvice: String(parsed.preventiveAdvice ?? 'Consult a healthcare provider for personalized advice.').trim() || 'Consult a healthcare provider for personalized advice.',
    isRuleBased: false,
  };
}

/** When JSON.parse fails (e.g. unterminated string), try to extract fields with regex. */
function parseJsonInsightFallback(cleaned) {
  const out = {};
  const riskMatch = cleaned.match(/"riskLevel"\s*:\s*"([^"]*)"/);
  if (riskMatch) out.riskLevel = riskMatch[1].trim();
  const catMatch = cleaned.match(/"conditionCategory"\s*:\s*"([^"]*)"/);
  if (catMatch) out.conditionCategory = catMatch[1].trim();
  const sumMatch = cleaned.match(/"summaryText"\s*:\s*"((?:[^"\\]|\\.)*?)"\s*,\s*"riskLevel"/)
    || cleaned.match(/"summaryText"\s*:\s*"((?:[\s\S])*?)(?="\s*,\s*"riskLevel")/);
  if (sumMatch) out.summaryText = sumMatch[1].replace(/\\./g, (m) => (m === '\\n' ? '\n' : m === '\\"' ? '"' : m)).trim();
  const advMatch = cleaned.match(/"preventiveAdvice"\s*:\s*"((?:[^"\\]|\\.)*?)"\s*}/)
    || cleaned.match(/"preventiveAdvice"\s*:\s*"((?:[\s\S])*?)"\s*}\s*$/);
  if (advMatch) out.preventiveAdvice = advMatch[1].replace(/\\./g, (m) => (m === '\\n' ? '\n' : m === '\\"' ? '"' : m)).trim();
  if (out.riskLevel || out.conditionCategory || out.summaryText || out.preventiveAdvice) return out;
  return null;
}

// ── Rule-based fallback ───────────────────────────────────────────────────────

function generateFallbackInsight(vitals, nothingMeasured, llmErrorMessage, lang = 'en') {
  const v = vitals || {};
  const t = FALLBACK_STRINGS[lang] || FALLBACK_STRINGS.en;
  const labels = ISSUE_LABELS[lang] || ISSUE_LABELS.en;

  if (nothingMeasured) {
    return {
      summaryText: t.noMeasurements,
      riskLevel: 'low',
      conditionCategory: 'normal',
      preventiveAdvice: t.noMeasurementsAdvice,
      isRuleBased: true,
    };
  }

  const issues = [];
  let riskLevel = 'low';

  const systolic = v.systolicBP;
  const diastolic = v.diastolicBP;
  if (systolic != null && diastolic != null) {
    if (systolic > 140 || diastolic > 90) {
      issues.push(labels.elevatedBP);
      riskLevel = systolic > 180 ? 'critical' : 'high';
    }
  }
  if (v.spo2 != null && v.spo2 < 95) {
    issues.push(labels.lowSpo2);
    riskLevel = v.spo2 < 90 ? 'critical' : 'high';
  }
  if (v.heartRate != null) {
    if (v.heartRate > 100) issues.push(labels.elevatedHR);
    if (v.heartRate < 60) issues.push(labels.lowHR);
  }
  if (v.temperatureCelsius != null && v.temperatureCelsius > 37.5) {
    issues.push(labels.elevatedTemp);
    if (riskLevel === 'low') riskLevel = 'moderate';
  }
  if (v.bmi != null && v.bmi > 30) {
    issues.push(labels.obesity);
    if (riskLevel === 'low') riskLevel = 'moderate';
  }

  const conditionCategory = issues.length === 0
    ? 'normal'
    : issues.includes(labels.elevatedBP)
      ? 'hypertension'
      : issues.includes(labels.lowSpo2)
        ? 'respiratory concern'
        : 'general concern';

  const ruleSummary = issues.length === 0
    ? t.allNormal
    : t.detected(issues);

  const summaryText = llmErrorMessage
    ? t.llmFailed(ruleSummary, llmErrorMessage)
    : ruleSummary;

  return {
    summaryText,
    riskLevel,
    conditionCategory,
    preventiveAdvice: issues.length === 0 ? t.normalAdvice : t.issueAdvice,
    isRuleBased: true,
  };
}

module.exports = { analyzeVitals };
