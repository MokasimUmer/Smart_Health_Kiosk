/// All user-facing strings for the app.
/// Add new keys here first, then provide translations in [_am] and [_om].
class AppStrings {
  final String languageCode;
  const AppStrings._(this.languageCode);

  static const AppStrings en = AppStrings._('en');
  static const AppStrings am = AppStrings._('am');
  static const AppStrings om = AppStrings._('om');

  static AppStrings fromCode(String code) {
    switch (code) {
      case 'am': return am;
      case 'om': return om;
      default:   return en;
    }
  }

  // ── General ──────────────────────────────────────────────────────────────
  String get appTitle => _s('Smart Health Kiosk', 'ስማርት ጤና ኪዮስክ', 'Kiyooskii Fayyaa Sammuu');
  String get ok => _s('OK', 'እሺ', 'Tole');
  String get cancel => _s('Cancel', 'ሰርዝ', 'Haqi');
  String get save => _s('Save', 'አስቀምጥ', 'Kuusi');
  String get retry => _s('Retry', 'እንደገና ሞክር', 'Irra deebi\'i yaalii');
  String get skip => _s('Skip', 'ዝለል', 'Irri ce\'i');
  String get error => _s('Error', 'ስህተት', 'Dogoggora');
  String get loading => _s('Loading...', 'በመጫን ላይ...', 'Fe\'aa jira...');

  // ── Auth ─────────────────────────────────────────────────────────────────
  String get signIn => _s('Sign In', 'ግባ', 'Seeni');
  String get signInToContinue => _s('Sign in to continue', 'ለመቀጠል ይግቡ', 'Itti fufuuf seeni');
  String get phoneNumber => _s('Phone Number', 'ስልክ ቁጥር', 'Lakkoofsa Bilbilaa');
  String get password => _s('Password', 'የይለፍ ቃል', 'Jecha Icciitii');
  String get dontHaveAccount => _s(
    "Don't have an account? Sign Up",
    'መለያ የለዎትም? ይመዝገቡ',
    'Akkaawuntii hin qabdu? Galmaa\'i',
  );
  String get loginFailed => _s('Login failed', 'መግባት አልተሳካም', 'Seenuun hin milkoofne');
  String get cannotReachServer => _s(
    'Cannot reach server. Check: phone and PC on same Wi‑Fi, backend running (npm start), and PC firewall allows port 5000.',
    'ሰርቨርን ማግኘት አልተቻለም። ያረጋግጡ: ስልክ እና ፒሲ በተመሳሳይ ዋይ-ፋይ ላይ፣ ባክኤንድ እየሰራ (npm start)፣ እና ፋየርዎል ፖርት 5000 ይፈቅዳል።',
    'Sarvaara bira ga\'uu hin danda\'amne. Mirkaneessi: bilbilaa fi PC Wi-Fi tokkorra, backend hojjechaa jira (npm start), fi firewall PC port 5000 hayyama.',
  );
  String networkError(String msg) => _s(
    'Network error: $msg',
    'የኔትወርክ ስህተት: $msg',
    'Dogoggora network: $msg',
  );

  // ── Sign Up ───────────────────────────────────────────────────────────────
  String get createAccount => _s('Create Account', 'መለያ ይፍጠሩ', 'Akkaawuntii Uumi');
  String get fullName => _s('Full Name', 'ሙሉ ስም', 'Maqaa Guutuu');
  String get signupFailed => _s('Signup failed', 'ምዝገባ አልተሳካም', 'Galma\'uun hin milkoofne');

  // ── Home ─────────────────────────────────────────────────────────────────
  String welcome(String name) => _s('Welcome, $name', 'እንኳን ደህና መጡ፣ $name', 'Baga nagaan dhuftan, $name');
  String subscriptionStatus(String status) => _s(
    'Subscription: $status',
    'ምዝገባ: $status',
    'Galma\'ina: $status',
  );
  String get subscriptionRequired => _s('Subscription Required', 'ምዝገባ ያስፈልጋል', 'Galma\'inni Barbaachisaa');
  String get pleaseSubscribe => _s(
    'Please subscribe to access kiosk features',
    'የኪዮስክ ባህሪያትን ለመጠቀም እባክዎ ይመዝገቡ',
    'Amaloota kiyooskii fayyadamuuf maaloo galmaa\'i',
  );
  String get subscribeNow => _s('Subscribe Now', 'አሁን ይመዝገቡ', 'Amma Galmaa\'i');
  String get startMeasurement => _s('Start Measurement', 'መለኪያ ጀምር', 'Safartuu Jalqabi');
  String get connectToKiosk => _s(
    'Connect to kiosk and measure vitals',
    'ከኪዮስክ ጋር ተገናኝ እና ህይወታዊ ምልክቶችን ይለኩ',
    'Kiyooskii waliin wal qunnamsiisi fi mallattoolee jireenyaa safarti',
  );
  String get measurementHistory => _s('Measurement History', 'የመለኪያ ታሪክ', 'Seenaa Safartuu');
  String get viewPastMeasurements => _s(
    'View past measurements and insights',
    'ያለፉ መለኪያዎችን እና ግንዛቤዎችን ይመልከቱ',
    'Safartuuwwan darban fi hubannoo ilaali',
  );
  String get myAppointments => _s('My Appointments', 'የእኔ ቀጠሮዎች', 'Beellama Koo');
  String get viewAppointmentStatus => _s(
    'View appointment status',
    'የቀጠሮ ሁኔታን ይመልከቱ',
    'Haala beellamaa ilaali',
  );
  String get loggedOut => _s('Logged out', 'ወጥተዋል', 'Ba\'eera');
  String get logout => _s('Logout', 'ውጣ', 'Ba\'i');

  // ── Appointments ─────────────────────────────────────────────────────────
  String get appointmentsTitle => _s('My Appointments', 'የእኔ ቀጠሮዎች', 'Beellama Koo');
  String get noAppointments => _s('No appointments yet', 'እስካሁን ቀጠሮ የለም', 'Beellama ammaaf hin jiru');
  String condition(String c) => _s('Condition: $c', 'ሁኔታ: $c', 'Haala: $c');
  String feeAndDate(String fee, String date) => _s(
    'Fee: $fee ETB  |  $date',
    'ክፍያ: $fee ብር  |  $date',
    'Kaffaltii: $fee ETB  |  $date',
  );
  String appointment(String dt) => _s('Appointment: $dt', 'ቀጠሮ: $dt', 'Beellama: $dt');
  String reason(String r) => _s('Reason: $r', 'ምክንያት: $r', 'Sababa: $r');

  // ── History ───────────────────────────────────────────────────────────────
  String get historyTitle => _s('Measurement History', 'የመለኪያ ታሪክ', 'Seenaa Safartuu');
  String get noMeasurements => _s('No measurements yet', 'እስካሁን መለኪያ የለም', 'Safartuu ammaaf hin jiru');
  String get pendingSync => _s('Pending sync', 'ሲንክ በመጠባበቅ ላይ', 'Sync eegaa jira');
  String get synced => _s('Synced', 'ተሲንክሯል', 'Sync ta\'eera');
  String get pendingSyncChip => _s('Pending sync', 'ሲንክ በመጠባበቅ', 'Sync eegaa');
  String kioskLabel(String id) => _s('Kiosk: $id', 'ኪዮስክ: $id', 'Kiyooskii: $id');

  // ── Kiosk ─────────────────────────────────────────────────────────────────
  String get kioskTitle => _s('Kiosk Measurement', 'የኪዮስክ መለኪያ', 'Safartuu Kiyooskii');
  String get notConnected => _s('Not connected', 'አልተገናኘም', 'Wal hin qunnamne');
  String get connecting => _s('Connecting...', 'በማገናኘት ላይ...', 'Wal qunnamsiisaa jira...');
  String connected(String id) => _s('Connected to $id', 'ከ$id ጋር ተገናኝቷል', '$id waliin wal qunname');
  String get connectionFailed => _s('Connection failed', 'ግንኙነት አልተሳካም', 'Wal qunnamtiin hin milkoofne');
  String get kioskIpLabel => _s('Kiosk IP Address', 'የኪዮስክ አይፒ አድራሻ', 'Teessoo IP Kiyooskii');
  String get kioskIpHint => '192.168.137.204';
  String get kioskNetworkHint => _s(
    'Ensure the Pi is on the same network and the sensor server is running.',
    'ፒ ተመሳሳይ ኔትወርክ ላይ መሆኑን እና የሴንሰር ሰርቨሩ እየሰራ መሆኑን ያረጋግጡ።',
    'Pi network tokkorra akka jiru fi sarvaara sensor hojjechaa akka jiru mirkaneessi.',
  );
  String get connectToKioskBtn => _s('Connect to Kiosk', 'ከኪዮስክ ጋር ተገናኝ', 'Kiyooskii waliin wal qunnamsi');
  String get skipKiosk => _s(
    'Skip — use app without kiosk',
    'ዝለል — ያለ ኪዮስክ ይጠቀሙ',
    'Irri ce\'i — kiyooskii malee app fayyadami',
  );
  String get readyToMeasure => _s('Ready to Measure', 'ለመለካት ዝግጁ', 'Safaruuf Qophaa\'e');
  String get readyInstructions => _s(
    'Place your arm in the cuff, finger on the oximeter, and stand on the scale.',
    'ክንድዎን ወደ ካፍ ያስገቡ፣ ጣትዎን ወደ ኦክሲሜትሩ ያስቀምጡ፣ እና ሚዛን ላይ ይቁሙ።',
    'Harka kee cuff keessa kaa\'i, quba oximeter irratti kaa\'i, fi miizana irratti dhaabadhu.',
  );
  String get startMeasurementBtn => _s('Start Measurement', 'መለኪያ ጀምር', 'Safartuu Jalqabi');

  // ── Measurement flow ──────────────────────────────────────────────────────
  String get measurementFlowTitle => _s('Kiosk Measurement', 'የኪዮስክ መለኪያ', 'Safartuu Kiyooskii');
  String stepOf(int current, int total) => _s(
    'Step $current of $total',
    'ደረጃ $current ከ $total',
    'Tartiiba $current kan $total',
  );
  String getReadyFor(String label) => _s(
    'Get ready for $label',
    'ለ$label ይዘጋጁ',
    '$label qopheessi',
  );
  String getReadyCountdown(int n) => _s(
    'Get ready... $n',
    'ይዘጋጁ... $n',
    'Qophaa\'i... $n',
  );
  String get measuring => _s('Measuring...', 'በመለካት ላይ...', 'Safaraa jira...');
  String measuringLabel(String label) => _s(
    'Measuring $label...',
    '$label እየለካ...',
    '$label safaraa jira...',
  );
  String get pleaseWaitSensor => _s(
    'Please wait for sensor...',
    'እባክዎ ሴንሰሩን ይጠብቁ...',
    'Maaloo sensor eegaa...',
  );
  String get sensorNotDetected => _s('Sensor not detected', 'ሴንሰር አልተገኘም', 'Sensor hin argamne');
  String sensorNotDetectedMsg(String label) => _s(
    '$label sensor not detected. Please correct the sensor and retry, or skip to the next.',
    'የ$label ሴንሰር አልተገኘም። ሴንሰሩን አስተካክለው እንደገና ሞክሩ፣ ወይም ቀጣዩን ዝለሉ።',
    'Sensor $label hin argamne. Maaloo sensor sirreessi irra deebi\'i yaalii, ykn itti aanaa irri ce\'i.',
  );
  String nextStepIn(int n) => _s('Next step in ${n}s', 'ቀጣይ ደረጃ በ${n}ሰ', 'Tartiiba itti aanu ${n}s keessatti');
  String get measurementComplete => _s('Measurement complete', 'መለካት ተጠናቋል', 'Safartuu xumurame');
  String get savedLocally => _s(
    'Saved locally. Will sync when online.',
    'በአካባቢ ተቀምጧል። ኦንላይን ሲሆን ይሲንካል።',
    'Naannoo keessatti kuufame. Online yoo ta\'e sync ta\'a.',
  );

  // ── Measurement summary ───────────────────────────────────────────────────
  String get summaryTitle => _s('Measurement Summary', 'የመለኪያ ማጠቃለያ', 'Cuunfaa Safartuu');
  String get vitalSigns => _s('Vital signs', 'ህይወታዊ ምልክቶች', 'Mallattoolee Jireenyaa');
  String get bloodPressure => _s('Blood Pressure', 'የደም ግፊት', 'Dhiibbaa Dhiigaa');
  String get height => _s('Height', 'ቁመት', 'Dheerina');
  String get weight => _s('Weight', 'ክብደት', 'Ulfaatina');
  String get heartRate => _s('Heart Rate', 'የልብ ምት', 'Saffisa Onnee');
  String get spo2 => 'SpO2';
  String get temperature => _s('Temperature', 'ሙቀት', 'Ho\'a');
  String get bmi => 'BMI';
  String get skipped => _s('Skipped', 'ተዝሏል', 'Irri ce\'ame');
  String get doneViewResults => _s(
    'Done – View results & insights',
    'ጨርሷል – ውጤቶችን እና ግንዛቤዎችን ይመልከቱ',
    'Xumurame – Bu\'aawwan fi hubannoo ilaali',
  );
  String get remeasure => _s('Re-measure', 'እንደገና ይለኩ', 'Irra deebi\'ii safarti');

  // ── Results ───────────────────────────────────────────────────────────────
  String get resultsTitle => _s('Results & AI Insights', 'ውጤቶች እና AI ግንዛቤዎች', 'Bu\'aawwan fi Hubannoo AI');
  String get analyzingVitals => _s(
    'Analyzing your vitals...',
    'ህይወታዊ ምልክቶችዎን በመተንተን ላይ...',
    'Mallattoolee jireenyaa kee xiinxalaa jira...',
  );
  String get retryAnalysis => _s('Retry analysis', 'ትንተናን እንደገና ሞክር', 'Xiinxala irra deebi\'i yaalii');
  String get healthSummaryRuleBased => _s(
    'Health summary (rule-based)',
    'የጤና ማጠቃለያ (ደንብ-ተኮር)',
    'Cuunfaa fayyaa (seera-bu\'uureffame)',
  );
  String get aiHealthInsight => _s('AI Health Insight', 'AI የጤና ግንዛቤ', 'Hubannoo Fayyaa AI');
  String get categoryLabel => _s('Category: ', 'ምድብ: ', 'Gosa: ');
  String get adviceLabel => _s('Advice: ', 'ምክር: ', 'Gorsa: ');
  String get disclaimer => _s(
    'This is NOT a clinical diagnosis. Please consult a healthcare professional.',
    'ይህ ክሊኒካዊ ምርመራ አይደለም። እባክዎ የጤና ባለሙያ ያማክሩ።',
    'Kun murtoo kilinikaa MITI. Maaloo ogeeyyii fayyaa mari\'adhu.',
  );
  String get viewSuggestedHospitals => _s(
    'View Suggested Hospitals',
    'የሚጠቆሙ ሆስፒታሎችን ይመልከቱ',
    'Hospitaaloota Yaadaman Ilaali',
  );
  // Results screen UI
  String get latestCheckup => _s('Latest Checkup', 'የቅርብ ጊዜ ምርመራ', 'Sakatta\'a Haaraa');
  String get overallHealthy => _s('Overall Healthy', 'በአጠቃላይ ጤናማ', 'Fayyaa Waliigalaa');
  String get overallModerate => _s('Needs Attention', 'ትኩረት ያስፈልጋል', 'Xiyyeeffannoo Barbaada');
  String get overallCritical => _s('Critical — See Doctor', 'ወሳኝ — ሐኪም ያማክሩ', 'Hamaa — Ogeessa Fayyaa Barbaadi');
  String get vitalsLookGood => _s('Your vitals are looking good today.', 'ዛሬ ህይወታዊ ምልክቶችዎ ጥሩ ናቸው።', 'Mallattooleen jireenyaa kee har\'a gaarii dha.');
  String get vitalsNeedAttention => _s('Some vitals need attention.', 'አንዳንድ ህይወታዊ ምልክቶች ትኩረት ያስፈልጋቸዋል።', 'Mallattooleen jireenyaa tokko tokko xiyyeeffannoo barbaadu.');
  String get vitalsCritical => _s('Critical vitals detected. Seek care immediately.', 'ወሳኝ ህይወታዊ ምልክቶች ተገኝተዋል። ወዲያውኑ እርዳታ ይፈልጉ።', 'Mallattoolee jireenyaa hamaa argame. Hatattamaan gargaarsa barbaadi.');
  String get quickActions => _s('Quick Actions', 'ፈጣን እርምጃዎች', 'Tarkaanfii Ariifataa');
  String get askDoctorAI => _s('Ask Doctor AI', 'AI ሐኪምን ጠይቅ', 'Dokitara AI Gaafadhu');
  String get getInstantAdvice => _s('Get instant health advice', 'ፈጣን የጤና ምክር ያግኙ', 'Gorsa fayyaa hatattamaa argadhu');
  String get history => _s('History', 'ታሪክ', 'Seenaa');
  String get findClinic => _s('Find Clinic', 'ክሊኒክ ፈልግ', 'Kilinika Barbaadi');
  String get healthTip => _s('Health Tip', 'የጤና ምክር', 'Gorsa Fayyaa');
  String get noDate => _s('Today', 'ዛሬ', 'Har\'a');
  // Vital status labels
  String get statusNormal => _s('Normal', 'ተለምዷዊ', 'Idilee');
  String get statusHigh => _s('High', 'ከፍ ያለ', 'Ol\'aanaa');
  String get statusLow => _s('Low', 'ዝቅ ያለ', 'Gadi aanaa');
  String get statusElevated => _s('Elevated', 'ከፍ ያለ', 'Ol\'aanaa');
  String get statusNormalOxygen => _s('Normal Oxygen', 'ተለምዷዊ ኦክሲጅን', 'Oksijiinii Idilee');
  String get statusLowOxygen => _s('Low Oxygen', 'ዝቅተኛ ኦክሲጅን', 'Oksijiinii Gadi Aanaa');
  String get statusFever => _s('Fever', 'ትኩሳት', 'Ho\'a Qaamaa');
  String get statusObese => _s('Obese', 'ውፍረት', 'Furdaa');
  String get statusOverweight => _s('Overweight', 'ክብደት ከፍ ያለ', 'Ulfaatina Ol\'aanaa');
  String get statusUnderweight => _s('Underweight', 'ክብደት ዝቅ ያለ', 'Ulfaatina Gadi Aanaa');
  String get aiInsightTitle => _s('AI Health Insights', 'AI የጤና ግንዛቤዎች', 'Hubannoo Fayyaa AI');
  String get tapToExpand => _s('Tap to view full analysis', 'ሙሉ ትንተና ለማየት ይጫኑ', 'Xiinxala guutuu ilaaluuf tuqi');
  String get noInsightYet => _s('Analysis in progress...', 'ትንተና በሂደት ላይ...', 'Xiinxalli deemaa jira...');
  String get healthTip1 => _s(
    'Drink 2 liters of water daily to stay hydrated in the heat.',
    'ሙቀቱ ውስጥ እርጥበት ለመጠበቅ በቀን 2 ሊትር ውሃ ይጠጡ።',
    'Ho\'a keessatti qorichaa ta\'uuf guyyaa guyyaan lita 2 bishaanii dhugaa.',
  );
  String get healthTip2 => _s(
    'Walk at least 30 minutes a day to keep your heart healthy.',
    'ልብዎን ጤናማ ለማቆየት በቀን ቢያንስ 30 ደቂቃ ይራመዱ።',
    'Onnee kee fayyaalessa ta\'uuf guyyaa guyyaan daqiiqaa 30 yoo xiqqaate deemi.',
  );
  String get healthTip3 => _s(
    'Get 7-8 hours of sleep each night for better health.',
    'ለተሻለ ጤና በሌሊት 7-8 ሰዓት ይተኙ።',
    'Fayyaa gaarii argachuuf halkan saatii 7-8 rafii.',
  );

  // ── Hospital selection ────────────────────────────────────────────────────
  String get suggestedHospitals => _s('Suggested Hospitals', 'የሚጠቆሙ ሆስፒታሎች', 'Hospitaaloota Yaadaman');
  String get registeredHospitals => _s('Registered Hospitals', 'የተመዘገቡ ሆስፒታሎች', 'Hospitaaloota Galma\'an');
  String get otherNearbyHospitals => _s('Other Nearby Hospitals', 'ሌሎች አቅራቢያ ሆስፒታሎች', 'Hospitaaloota Biroo Dhiyoo Jiran');
  String bookAt(String name) => _s(
    'Book Appointment at $name',
    'በ$name ቀጠሮ ያስይዙ',
    '$name irratti Beellama Qabadhu',
  );
  String bookingFee(String fee) => _s(
    'Booking fee: $fee ETB',
    'የቦታ ማስያዣ ክፍያ: $fee ብር',
    'Kaffaltii beellama: $fee ETB',
  );
  String get paymentMethod => _s('Payment Method', 'የክፍያ ዘዴ', 'Mala Kaffaltii');
  String get uploadPaymentReceipt => _s('Upload Payment Receipt', 'የክፍያ ደረሰኝ ይጫኑ', 'Mirkaneessa Kaffaltii Fe\'i');
  String get receiptSelected => _s('Receipt Selected', 'ደረሰኝ ተመርጧል', 'Mirkaneessi Filatame');
  String get submitAppointmentRequest => _s(
    'Submit Appointment Request',
    'የቀጠሮ ጥያቄ ያስገቡ',
    'Gaaffii Beellama Dhiyeessi',
  );
  String get appointmentSent => _s(
    'Appointment request sent! Waiting for hospital confirmation.',
    'የቀጠሮ ጥያቄ ተልኳል! የሆስፒታሉን ማረጋገጫ በመጠባበቅ ላይ።',
    'Gaaffiin beellama ergame! Mirkaneessa hospitaalaa eegaa jira.',
  );
  String get failed => _s('Failed', 'አልተሳካም', 'Hin milkoofne');
  String kmAway(String dist) => _s('$dist km away', '$dist ኪሜ ርቀት', '$dist km fagaata');
  String hospitalFee(String fee) => _s('Fee: $fee ETB', 'ክፍያ: $fee ብር', 'Kaffaltii: $fee ETB');

  // ── Subscription ──────────────────────────────────────────────────────────
  String get subscribeTitle => _s('Subscribe', 'ይመዝገቡ', 'Galmaa\'i');
  String get annualSubscription => _s('Annual Subscription', 'ዓመታዊ ምዝገባ', 'Galma\'ina Waggaa');
  String get subscriptionInstructions => _s(
    'Pay via bank transfer, Telebirr, or CBE Birr, then upload your receipt below.',
    'በባንክ ዝውውር፣ ቴሌብር፣ ወይም CBE ብር ይክፈሉ፣ ከዚያ ደረሰኝዎን ከዚህ በታች ይጫኑ።',
    'Dabarsaa baankii, Telebirr, ykn CBE Birr\'n kaffalti, itti aansuun mirkaneessa kee gad fe\'i.',
  );
  String get subscriptionAmount => _s('Amount: 500 ETB / year', 'መጠን: 500 ብር / ዓመት', 'Baasii: 500 ETB / waggaa');
  String get amountEtb => _s('Amount (ETB)', 'መጠን (ብር)', 'Baasii (ETB)');
  String get uploadReceiptPhoto => _s('Upload Receipt Photo', 'የደረሰኝ ፎቶ ይጫኑ', 'Suuraa Mirkaneessaa Fe\'i');
  String get pleaseSelectReceipt => _s(
    'Please select a receipt image',
    'እባክዎ የደረሰኝ ምስል ይምረጡ',
    'Maaloo suuraa mirkaneessaa filadhu',
  );
  String get submitSubscriptionRequest => _s(
    'Submit Subscription Request',
    'የምዝገባ ጥያቄ ያስገቡ',
    'Gaaffii Galma\'inaa Dhiyeessi',
  );
  String get subscriptionSubmitted => _s(
    'Subscription request submitted! Waiting for admin approval.',
    'የምዝገባ ጥያቄ ቀርቧል! የአስተዳዳሪ ፈቃድ በመጠባበቅ ላይ።',
    'Gaaffiin galma\'inaa dhiyaate! Hayyama bulchiinsaa eegaa jira.',
  );

  // ── Server config ─────────────────────────────────────────────────────────
  String get serverSettingsTitle => _s('Server Settings', 'የሰርቨር ቅንብሮች', 'Qindaa\'ina Sarvaara');
  String get backendServerIp => _s('Backend Server IP', 'የባክኤንድ ሰርቨር አይፒ', 'IP Sarvaara Backend');
  String get serverIpInstructions => _s(
    'Enter your PC\'s IPv4 address (run "ipconfig" on Windows or "ifconfig" on Mac/Linux). Your phone and PC must be on the same Wi-Fi.',
    'የፒሲዎን IPv4 አድራሻ ያስገቡ (በዊንዶውስ "ipconfig" ወይም ማክ/ሊኑክስ "ifconfig" ያሂዱ)። ስልክዎ እና ፒሲዎ ተመሳሳይ ዋይ-ፋይ ላይ መሆን አለባቸው።',
    'Teessoo IPv4 PC kee galchi (Windows irratti "ipconfig" ykn Mac/Linux irratti "ifconfig" oofii). Bilbilaa fi PC kee Wi-Fi tokkorra ta\'uu qabu.',
  );
  String get pcIpAddress => _s('PC IP Address', 'የፒሲ አይፒ አድራሻ', 'Teessoo IP PC');
  String get pcIpHint => _s('e.g. 192.168.1.100', 'ለምሳሌ 192.168.1.100', 'fkn. 192.168.1.100');
  String get portNote => _s(
    'Port 5000 is used automatically.',
    'ፖርት 5000 በራስ-ሰር ጥቅም ላይ ይውላል።',
    'Port 5000 ofumaan fayyadama.',
  );
  String get testConnection => _s('Test Connection', 'ግንኙነት ሞክር', 'Wal qunnamtii Yaalii');
  String serverReachable(String ip) => _s(
    'Server reachable at $ip:5000 ✓',
    'ሰርቨር በ$ip:5000 ይደርሳል ✓',
    'Sarvaara $ip:5000 irratti argama ✓',
  );
  String serverUnreachable(String ip) => _s(
    'Could not reach $ip:5000 — check Wi-Fi and that the backend is running.',
    '$ip:5000 ማግኘት አልተቻለም — ዋይ-ፋይ እና ባክኤንድ እየሰራ መሆኑን ያረጋግጡ።',
    '$ip:5000 bira ga\'uu hin danda\'amne — Wi-Fi fi backend hojjechaa akka jiru mirkaneessi.',
  );
  String get serverIpSaved => _s('Server IP saved', 'የሰርቨር አይፒ ተቀምጧል', 'IP sarvaara kuufame');

  // ── Language picker ───────────────────────────────────────────────────────
  String get language => _s('Language', 'ቋንቋ', 'Afaan');
  String get selectLanguage => _s('Select Language', 'ቋንቋ ይምረጡ', 'Afaan Filadhu');
  String get langEnglish => 'English';
  String get langAmharic => 'አማርኛ';
  String get langAfaanOromo => 'Afaan Oromoo';

  // ── Internal helper ───────────────────────────────────────────────────────
  String _s(String en, String am, String om) {
    switch (languageCode) {
      case 'am': return am;
      case 'om': return om;
      default:   return en;
    }
  }
}
