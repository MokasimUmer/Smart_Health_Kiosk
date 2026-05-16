/**
 * Health insight from vitals. Supports Google Gemini and OpenAI-style APIs.
 * Set LLM_PROVIDER=gemini and LLM_API_KEY=your_google_api_key for Gemini.
 * Supports language codes: 'en' (English), 'am' (Amharic), 'om' (Afaan Oromo).
 */

const { jsonrepair } = require('jsonrepair');

// ── Language-specific system prompts ────────────────────────────────────────

const SYSTEM_PROMPT_EN = `You are a health assistant. Given vital signs, reply with ONLY a valid JSON object (no markdown, no extra text):
{"summaryText":"2-3 sentence plain-language summary","riskLevel":"low|moderate|high|critical","conditionCategory":"short English label e.g. normal, respiratory concern, obesity","preventiveAdvice":"1-2 sentences of advice","rankKeywords":["english-token-1","english-token-2"]}

Output language: summaryText and preventiveAdvice must be entirely in English.

conditionCategory must always be a short English phrase (for internal routing), even if other fields are localized elsewhere.

rankKeywords: exactly two short English tokens (1-2 words each, lowercase when possible) for matching nearby hospital NAMES and specialties — e.g. heart/chest issues use ["cardiac","heart"]; breathing/SpO2 use ["respiratory","lung"]; obesity use ["nutrition","weight"]; otherwise use tokens that fit conditionCategory.

Use WHO norms: HR 60-100, SpO2 95-100%, Temp 36.1-37.2°C, BMI 18.5-24.9. This is NOT a diagnosis; do not replace a doctor.
If most values are N/A or only one vital was measured, say so in summaryText and suggest measuring more vitals; do not claim "all vital signs are within normal ranges" when most data is missing.
Important: Output must be valid JSON. Use only double quotes for strings; escape any double quote inside a string as \\" or as \\u0022. Do not put raw line breaks inside JSON string values. Keep summaryText and preventiveAdvice concise.`;

const SYSTEM_PROMPT_AM = `እርስዎ የጤና ረዳት ነዎት። የህይወት ምልክቶች ሲሰጡ፣ ONLY ትክክለኛ JSON ነገር ይመልሱ (markdown ወይም ተጨማሪ ጽሑፍ አይጨምሩ):
{"summaryText":"...","riskLevel":"low|moderate|high|critical","conditionCategory":"short English only e.g. respiratory concern","preventiveAdvice":"...","rankKeywords":["english-token-1","english-token-2"]}

የመልእክት ቋንቋ: summaryText እና preventiveAdvice በሙሉ በአማርኛ ይጻፉ። በዚህ ሁለት መስክ ውስጥ እንግሊዝኛ አይጨምሩ።

conditionCategory ሁልጊዜ አጭር እንግሊዝኛ ሀረግ ብቻ ይሁን (ለስርዓት ማመላለሻ)፣ ምሳሌ respiratory concern፣ obesity፣ normal።

rankKeywords: በትክክል ሁለት አጭር እንግሊዝኛ ቃላት (ለሆስፒታል ስም እና ስፔሻላይዜሽን ማመሳሰል) — ምሳሌ የልብ ["cardiac","heart"]፣ የመተንፈስ ["respiratory","lung"]።

የWHO ደረጃዎችን ይጠቀሙ: HR 60-100, SpO2 95-100%, ሙቀት 36.1-37.2°C, BMI 18.5-24.9. ይህ ምርመራ አይደለም; ሐኪምን አይተካም።
አብዛኛዎቹ እሴቶች N/A ከሆኑ ወይም አንድ ብቻ ከተለካ፣ ይህን በsummaryText ይጥቀሱ እና ተጨማሪ ምልክቶችን እንዲለኩ ይጠቁሙ።
አስፈላጊ: JSON ላይ የሚበላሹ ተጨማሪ ጽሑፍ አይጨምሩ። በስትሪንግ ውስጥ ያለን ጥቅስ በ\\" ያመልጡ። በስትሪንግ ውስጥ አዲስ መስመር አይጨምሩ። በsummaryText/preventiveAdvice ውስጥ የASCII \" (U+0022) ቁምፊ ካስፈለገ በ\\u0022 ይጻፍ።`;

const SYSTEM_PROMPT_OM = `Ati gargaaraa fayyaa dha. Mallattoolee jireenyaa yoo kenname, ONLY wantoota JSON sirrii ta'an deebisi (markdown ykn barruu dabalataa hin galchin):
{"summaryText":"...","riskLevel":"low|moderate|high|critical","conditionCategory":"short English only e.g. respiratory concern","preventiveAdvice":"...","rankKeywords":["english-token-1","english-token-2"]}

Afaan deebii: summaryText fi preventiveAdvice guutummaatti Afaan Oromootiin barreessi. Lammaffaa kana keessatti Ingiliffaa hin dabalin.

conditionCategory yeroo hunda jecha gabaabaa Ingiliffaa ta'uu qaba ( akka gargaarsa teeknikaa ), fakkeenya respiratory concern, obesity, normal.

rankKeywords: afaan Ingiliffaa jecha gabaabaa lama (maqaa hospitaalaa waliin walitti makuuf) — fkn. onnee ["cardiac","heart"], afuura ["respiratory","lung"].

Safartuu WHO fayyadami: HR 60-100, SpO2 95-100%, Ho'a 36.1-37.2°C, BMI 18.5-24.9. Kun murtoo kilinikaa MITI; ogeessa fayyaa bakka hin bu'u.
Gatiin hedduu N/A yoo ta'e ykn tokko qofa yoo safartame, summaryText keessatti ibsi fi mallattoolee dabalataa safaruuf gorsii.
Barbaachisaa: JSON keessatti barruu dabalataa hin galchin. String gidduu gabatee dachaa barreessuuf madaalliisa (backslash) fayyadami. String gidduu sarara haaraa hin galchin. Yoo gabatee dachaa (ASCII ") barreessuu barbaaddu, \\u0022 fayyadami.`;

function getSystemPrompt(language) {
  switch (language) {
    case 'am': return SYSTEM_PROMPT_AM;
    case 'om': return SYSTEM_PROMPT_OM;
    default: return SYSTEM_PROMPT_EN;
  }
}

/** patient = mobile app user reading their own insight; clinic = staff dashboard — third person. */
function getVoiceBlock(language, audience) {
  if (audience === 'clinic') {
    return '\n\nVOICE (clinical): Write for healthcare staff reviewing a record. Refer to the person as "the patient" / "the patient\'s" (third person). Do not use "you" for the patient.';
  }
  switch (language) {
    case 'am':
      return '\n\nድምፅ (ለተጠቃሚ): ይህን የሚያነበው መለኪያውን በስልክ ያደረገው ሰው ነው። summaryText እና preventiveAdvice በአንተ/ለአንተ/የአንተ ይጻፉ፤ «the patient» ወይም በሦስተኛ ሰው ለታካሚ አይጠቀሙ።';
    case 'om':
      return '\n\nSAFFISA (fayyadamtootaaf): Barruu kun safartuu bilbilaa irratti fudhatan irratti barreeffama. summaryText fi preventiveAdvice keessatti "si" "kee" fayyadami; "the patient" hin barreessin.';
    default:
      return '\n\nVOICE (patient app): The reader is the same person whose vitals these are. In summaryText and preventiveAdvice use second person only: "you" and "your". Never use "the patient".';
  }
}

function buildFullSystemPrompt(language, audience) {
  return `${getSystemPrompt(language)}${getVoiceBlock(language, audience)}`;
}

const VITAL_LABELS = {
  en: { hr: 'Heart rate', spo2: 'SpO2', temp: 'Temperature', weight: 'Weight', height: 'Height', bmi: 'BMI' },
  am: { hr: 'የልብ ምት', spo2: 'SpO2', temp: 'ሙቀት', weight: 'ክብደት', height: 'ቁመት', bmi: 'BMI' },
  om: { hr: 'Saffisa onnee', spo2: 'SpO2', temp: 'Ho\'a', weight: 'Ulfaatina', height: 'Dheerina', bmi: 'BMI' },
};

function buildUserMessage(vitals, patientHistory, language) {
  const lang = ['en', 'am', 'om'].includes(language) ? language : 'en';
  const L = VITAL_LABELS[lang] || VITAL_LABELS.en;
  const lines = [
    `${L.hr}: ${vitals.heartRate ?? 'N/A'} bpm | ${L.spo2}: ${vitals.spo2 ?? 'N/A'}%`,
    `${L.temp}: ${vitals.temperatureCelsius ?? 'N/A'}°C | ${L.weight}: ${vitals.weightKg ?? 'N/A'} kg | ${L.height}: ${vitals.heightCm ?? 'N/A'} cm | ${L.bmi}: ${vitals.bmi ?? 'N/A'}`,
  ];
  const tail = lang === 'am'
    ? 'በቋንቋው ትክክለኛ JSON ብቻ ይመልሱ።'
    : lang === 'om'
      ? 'JSON qofa sirnaan deebisi.'
      : 'Reply with only the JSON object.';
  const historyLine = patientHistory?.length
    ? `${lang === 'am' ? 'የቅርብ ታሪክ፡ ' : lang === 'om' ? 'Seenaa dhiyoo: ' : 'Recent history: '}${JSON.stringify(patientHistory)}`
    : '';
  const body = lines.join('\n');
  return historyLine ? `${body}\n${historyLine}\n\n${tail}` : `${body}\n\n${tail}`;
}

/** Gemini structured output — valid JSON even with Amharic/Oromo string contents. */
const GEMINI_INSIGHT_RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    summaryText: { type: 'STRING' },
    riskLevel: { type: 'STRING' },
    conditionCategory: { type: 'STRING' },
    preventiveAdvice: { type: 'STRING' },
    rankKeywords: {
      type: 'ARRAY',
      items: { type: 'STRING' },
    },
  },
  required: ['summaryText', 'riskLevel', 'conditionCategory', 'preventiveAdvice', 'rankKeywords'],
};

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
    lowSpo2: 'low oxygen saturation',
    elevatedHR: 'elevated heart rate',
    lowHR: 'low heart rate',
    elevatedTemp: 'elevated temperature',
    obesity: 'BMI indicates obesity',
  },
  am: {
    lowSpo2: 'ዝቅተኛ የኦክሲጅን ሙሌት',
    elevatedHR: 'ከፍ ያለ የልብ ምት',
    lowHR: 'ዝቅተኛ የልብ ምት',
    elevatedTemp: 'ከፍ ያለ ሙቀት',
    obesity: 'BMI ውፍረትን ያሳያል',
  },
  om: {
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
  if (v.heartRate != null || v.spo2 != null) return true;
  if (v.temperatureCelsius != null) return true;
  if (v.heightCm != null) return true;
  if (v.weightKg != null && v.weightKg !== 0) return true;
  if (v.bmi != null) return true;
  return false;
}

// ── Main entry point ─────────────────────────────────────────────────────────

async function analyzeVitals(vitals, patientHistory, language = 'en', audience = 'patient') {
  const lang = ['en', 'am', 'om'].includes(language) ? language : 'en';
  const aud = audience === 'clinic' ? 'clinic' : 'patient';
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

  console.log(`[LLM] Calling Gemini for analysis (lang=${lang}, audience=${aud})`);
  const systemPrompt = buildFullSystemPrompt(lang, aud);
  const userMessage = buildUserMessage(vitals, patientHistory, lang);

  try {
    if (provider === 'gemini') {
      return await callGemini(apiKey, userMessage, systemPrompt);
    }
    return await callOpenAI(apiKey, userMessage, systemPrompt);
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

const GEMINI_JSON_REPAIR_SUFFIX = `

(JSON output rules — follow exactly):
- Return ONE JSON object only, no markdown, no text before or after.
- Do not put raw line breaks inside any string value.
- If you must include a double-quote character inside summaryText or preventiveAdvice, use Unicode escape \\u0022 instead of ".
- Keep summaryText under 350 characters and preventiveAdvice under 250 characters (still in the requested human language).`;

async function callGemini(apiKey, userMessage, systemPrompt) {
  const model = getGeminiModel();
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`;

  const makeBody = (withSchema, userSuffix) => ({
    contents: [{ role: 'user', parts: [{ text: `${systemPrompt}\n\n${userMessage}${userSuffix || ''}` }] }],
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: 2048,
      ...(withSchema
        ? {
          responseMimeType: 'application/json',
          responseSchema: GEMINI_INSIGHT_RESPONSE_SCHEMA,
        }
        : {}),
    },
  });

  async function doRequest(withSchema, userSuffix) {
    let res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(makeBody(withSchema, userSuffix)),
    });

    if (!res.ok && res.status === 400 && withSchema) {
      console.warn('[LLM] Gemini JSON schema rejected; retrying without responseSchema');
      res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(makeBody(false, userSuffix)),
      });
    }
    return res;
  }

  let res = await doRequest(true, '');

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini ${res.status}: ${errText}`);
  }

  const parseResponseBody = async (response) => {
    const data = await response.json();
    const finishReason = data.candidates?.[0]?.finishReason;
    if (finishReason && finishReason !== 'STOP') {
      console.warn('[LLM] Gemini finishReason:', finishReason);
    }
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (text == null || String(text).trim() === '') {
      const blockReason = finishReason && finishReason !== 'STOP' ? ` finishReason=${finishReason}` : '';
      const promptFeedback = data.promptFeedback ? ` promptFeedback=${JSON.stringify(data.promptFeedback)}` : '';
      console.error('[LLM] Gemini returned no text.', blockReason, promptFeedback);
      throw new Error(`No text in Gemini response${blockReason || promptFeedback || ' (empty or blocked)'}`);
    }
    return String(text);
  };

  let text = await parseResponseBody(res);
  try {
    return parseJsonInsightSafe(text);
  } catch (e) {
    console.warn('[LLM] Gemini JSON parse failed, retrying with repair suffix:', e.message);
    console.error('[LLM] Raw (first 600 chars):', text.slice(0, 600));
    const res2 = await doRequest(true, GEMINI_JSON_REPAIR_SUFFIX);
    const res2b = !res2.ok ? await doRequest(false, GEMINI_JSON_REPAIR_SUFFIX) : res2;
    if (!res2b.ok) {
      const errText = await res2b.text();
      throw new Error(`Invalid JSON from Gemini (repair HTTP failed): ${e.message} | ${errText.slice(0, 200)}`);
    }
    text = await parseResponseBody(res2b);
    try {
      return parseJsonInsightSafe(text);
    } catch (e2) {
      console.error('[LLM] Gemini JSON parse failed after repair. Raw (first 800 chars):', text.slice(0, 800));
      throw new Error(`Invalid JSON from Gemini: ${e2.message}`);
    }
  }
}

async function callOpenAI(apiKey, userMessage, systemPrompt) {
  const apiUrl = process.env.LLM_API_URL || 'https://api.openai.com/v1/chat/completions';
  const model = process.env.LLM_MODEL || 'gpt-4';
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
  return parseJsonInsightSafe(text);
}

// ── JSON parsing ──────────────────────────────────────────────────────────────

function sanitizeJsonText(raw) {
  return String(raw)
    .replace(/\uFEFF/g, '')
    .replace(/[\u200B-\u200D\u2060]/g, '')
    .replace(/[\u201C\u201D]/g, '"')
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/```json\s*/gi, '')
    .replace(/```/g, '')
    .trim()
    .normalize('NFC');
}

/** Try strict parse, then jsonrepair (handles unclosed strings, trailing commas, etc.). */
function tryParseJsonWithRepair(s) {
  if (s == null || typeof s !== 'string') return null;
  const t = s.trim();
  if (!t) return null;
  try {
    return JSON.parse(t);
  } catch (_) {
    /* continue */
  }
  try {
    const repaired = jsonrepair(t);
    return JSON.parse(repaired);
  } catch (_) {
    return null;
  }
}

const _INSIGHT_JSON_KEYS = ['summaryText', 'riskLevel', 'conditionCategory', 'preventiveAdvice', 'rankKeywords'];

/**
 * End of a broken / multiline JSON string value: next field after `currentKey`.
 * Handles `,"key":`, newlines, and missing closing quote on the previous value.
 */
function _findNextJsonFieldBoundary(text, searchFrom, currentKey) {
  let best = -1;
  for (const k of _INSIGHT_JSON_KEYS) {
    if (k === currentKey) continue;
    const patterns = [
      `","${k}"`,
      `",\\s*"${k}"\\s*:`,
      `\\n\\s*"${k}"\\s*:`,
      `\\r\\n\\s*"${k}"\\s*:`,
    ];
    for (const pat of patterns) {
      const re = new RegExp(pat, 'g');
      re.lastIndex = Math.max(0, searchFrom);
      let m;
      while ((m = re.exec(text)) !== null) {
        const idx = m.index;
        if (idx >= searchFrom && (best === -1 || idx < best)) best = idx;
      }
    }
  }
  return best;
}

/** Extract top-level `{ ... }` honoring strings and escapes (handles Amharic inside quotes). */
function extractBalancedJsonObject(text) {
  const start = text.indexOf('{');
  if (start === -1) return null;
  let depth = 0;
  let inString = false;
  let escape = false;
  for (let i = start; i < text.length; i += 1) {
    const ch = text[i];
    if (escape) {
      escape = false;
      continue;
    }
    if (ch === '\\' && inString) {
      escape = true;
      continue;
    }
    if (ch === '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (ch === '{') depth += 1;
    else if (ch === '}') {
      depth -= 1;
      if (depth === 0) return text.slice(start, i + 1);
    }
  }
  return null;
}

/**
 * Read JSON string value for "key": "..." with full Unicode + \\uXXXX + escapes.
 * If the closing quote is missing (truncated / bad model output), slice up to the next `","otherKey"`.
 */
function extractJsonStringField(text, key) {
  const needle = `"${key}"`;
  const idx = text.indexOf(needle);
  if (idx === -1) return null;
  let i = idx + needle.length;
  while (i < text.length && /\s/.test(text[i])) i += 1;
  if (text[i] !== ':') return null;
  i += 1;
  while (i < text.length && /\s/.test(text[i])) i += 1;
  if (text[i] !== '"') return null;
  const valueStart = i + 1;
  i = valueStart;
  let out = '';
  while (i < text.length) {
    const c = text[i];
    if (c === '\\') {
      if (i + 1 >= text.length) break;
      const n = text[i + 1];
      if (n === 'n') out += '\n';
      else if (n === 't') out += '\t';
      else if (n === 'r') out += '\r';
      else if (n === '"') out += '"';
      else if (n === '\\') out += '\\';
      else if (n === 'u' && i + 5 < text.length) {
        const hex = text.slice(i + 2, i + 6);
        if (/^[0-9a-fA-F]{4}$/.test(hex)) {
          out += String.fromCharCode(parseInt(hex, 16));
          i += 6;
          continue;
        }
        out += n;
      } else out += n;
      i += 2;
      continue;
    }
    if (c === '"') {
      return out.trim();
    }
    out += c;
    i += 1;
  }
  const boundary = _findNextJsonFieldBoundary(text, valueStart, key);
  if (boundary !== -1 && boundary > valueStart) {
    return text.slice(valueStart, boundary).trim();
  }
  if (valueStart < text.length) {
    return text.slice(valueStart).trim();
  }
  return out.trim() || null;
}

function extractRankKeywordsFromLooseJson(text) {
  const key = '"rankKeywords"';
  const idx = text.indexOf(key);
  if (idx === -1) return null;
  let i = text.indexOf('[', idx + key.length);
  if (i === -1) return null;
  i += 1;
  const arr = [];
  while (i < text.length) {
    while (i < text.length && /[\s,]/.test(text[i])) i += 1;
    if (text[i] === ']') break;
    if (text[i] !== '"') break;
    i += 1;
    let s = '';
    while (i < text.length) {
      if (text[i] === '\\' && i + 1 < text.length) {
        const n = text[i + 1];
        if (n === 'u' && i + 5 < text.length) {
          const hex = text.slice(i + 2, i + 6);
          if (/^[0-9a-fA-F]{4}$/.test(hex)) {
            s += String.fromCharCode(parseInt(hex, 16));
            i += 6;
            continue;
          }
        }
        s += text[i + 1];
        i += 2;
        continue;
      }
      if (text[i] === '"') {
        i += 1;
        break;
      }
      s += text[i];
      i += 1;
    }
    const t = s.trim().toLowerCase();
    if (t) arr.push(t);
    if (arr.length >= 2) return arr.slice(0, 2);
  }
  return arr.length ? arr : null;
}

function parseJsonInsight(text) {
  if (text == null || typeof text !== 'string') throw new Error('Empty or invalid JSON');
  const cleaned = sanitizeJsonText(text);

  let parsed = tryParseJsonWithRepair(cleaned);
  if (!parsed) {
    const balanced = extractBalancedJsonObject(cleaned);
    if (balanced) parsed = tryParseJsonWithRepair(balanced);
  }

  if (!parsed) {
    try {
      const r1 = jsonrepair(cleaned);
      const r2 = jsonrepair(r1);
      parsed = JSON.parse(r2);
    } catch (_) {
      /* ignore */
    }
  }

  if (!parsed) {
    let fb = parseJsonInsightFallback(cleaned);
    if (!fb) {
      const balanced = extractBalancedJsonObject(cleaned);
      if (balanced) fb = parseJsonInsightFallback(balanced);
    }
    if (fb && (fb.summaryText || fb.preventiveAdvice || fb.conditionCategory || fb.riskLevel)) {
      parsed = fb;
    }
  }

  if (!parsed) {
    const scav = scavengeInsightFromText(cleaned);
    if (scav) parsed = scav;
  }

  if (!parsed || typeof parsed !== 'object') throw new Error('Empty or invalid JSON');
  return buildInsightResult(parsed);
}

/** Last-resort recovery after strict parse + jsonrepair + fallback. */
function scavengeInsightFromText(cleaned) {
  if (!cleaned) return null;
  let fb = parseJsonInsightFallback(cleaned);
  if (fb && (fb.summaryText || fb.preventiveAdvice || fb.conditionCategory || fb.riskLevel)) return fb;
  const bal = extractBalancedJsonObject(cleaned);
  if (bal) {
    fb = parseJsonInsightFallback(bal);
    if (fb && (fb.summaryText || fb.preventiveAdvice || fb.conditionCategory || fb.riskLevel)) return fb;
  }
  const s = cleaned.indexOf('{');
  const e = cleaned.lastIndexOf('}');
  if (s !== -1 && e > s) {
    fb = parseJsonInsightFallback(cleaned.slice(s, e + 1));
    if (fb && (fb.summaryText || fb.preventiveAdvice || fb.conditionCategory || fb.riskLevel)) return fb;
  }
  try {
    let t = cleaned;
    for (let i = 0; i < 3; i += 1) {
      t = jsonrepair(t);
    }
    const o = JSON.parse(t);
    if (o && typeof o === 'object') return o;
  } catch (_) {
    /* ignore */
  }
  return null;
}

function buildInsightResult(parsed) {
  let rankKeywords = [];
  if (Array.isArray(parsed.rankKeywords)) {
    rankKeywords = parsed.rankKeywords
      .map(x => String(x).toLowerCase().trim())
      .filter(Boolean)
      .slice(0, 2);
  }
  if (rankKeywords.length === 0) {
    rankKeywords = rankKeywordsFromConditionCategory(parsed.conditionCategory);
  }
  return {
    summaryText: String(parsed.summaryText ?? 'Summary not available.').trim() || 'Summary not available.',
    riskLevel: ['low', 'moderate', 'high', 'critical'].includes(parsed.riskLevel) ? parsed.riskLevel : 'low',
    conditionCategory: String(parsed.conditionCategory ?? 'normal').trim() || 'normal',
    preventiveAdvice: String(parsed.preventiveAdvice ?? 'Consult a healthcare provider for personalized advice.').trim() || 'Consult a healthcare provider for personalized advice.',
    rankKeywords,
    isRuleBased: false,
  };
}

function parseJsonInsightSafe(text) {
  try {
    return parseJsonInsight(text);
  } catch (e) {
    const cleaned = sanitizeJsonText(String(text));
    const fb = scavengeInsightFromText(cleaned);
    if (fb && (fb.summaryText || fb.preventiveAdvice || fb.conditionCategory || fb.riskLevel)) {
      console.warn('[LLM] Recovered partial insight after parse failure:', e.message);
      return buildInsightResult(fb);
    }
    throw e;
  }
}

function rankKeywordsFromConditionCategory(conditionCategory) {
  const cc = String(conditionCategory ?? 'normal').toLowerCase();
  if (!cc || cc === 'normal') return ['general', 'clinic'];
  const words = cc.split(/[\s,;/|]+/).filter(w => w.length > 2).slice(0, 2);
  if (words.length >= 2) return words;
  if (words.length === 1) return [words[0], 'care'];
  return ['general', 'clinic'];
}

/** When JSON.parse fails, extract fields without requiring ASCII-only regex paths. */
function parseJsonInsightFallback(cleaned) {
  const out = {};
  out.summaryText = extractJsonStringField(cleaned, 'summaryText');
  out.preventiveAdvice = extractJsonStringField(cleaned, 'preventiveAdvice');
  out.conditionCategory = extractJsonStringField(cleaned, 'conditionCategory');
  const risk = extractJsonStringField(cleaned, 'riskLevel');
  if (risk) out.riskLevel = risk.trim();
  const rk = extractRankKeywordsFromLooseJson(cleaned);
  if (rk && rk.length) out.rankKeywords = rk;
  if (out.summaryText || out.preventiveAdvice || out.conditionCategory || out.riskLevel) return out;
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
      rankKeywords: ['general', 'clinic'],
      isRuleBased: true,
    };
  }

  const issues = [];
  let riskLevel = 'low';

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
    : issues.includes(labels.lowSpo2)
      ? 'respiratory concern'
      : 'general concern';

  let rankKeywords;
  if (issues.includes(labels.lowSpo2)) {
    rankKeywords = ['respiratory', 'lung'];
  } else if (issues.includes(labels.elevatedHR) || issues.includes(labels.lowHR)) {
    rankKeywords = ['cardiac', 'heart'];
  } else if (issues.includes(labels.elevatedTemp)) {
    rankKeywords = ['fever', 'infection'];
  } else if (issues.includes(labels.obesity)) {
    rankKeywords = ['nutrition', 'weight'];
  } else {
    rankKeywords = rankKeywordsFromConditionCategory(conditionCategory);
  }

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
    rankKeywords,
    preventiveAdvice: issues.length === 0 ? t.normalAdvice : t.issueAdvice,
    isRuleBased: true,
  };
}

module.exports = { analyzeVitals };
