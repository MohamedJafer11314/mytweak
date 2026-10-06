#define UNICODE
#define _UNICODE

#include <windows.h>
#include <windowsx.h>
#include <shellapi.h>
#include <string>
#include <vector>
#include <algorithm>
#include <array>
#include <cmath>

static const wchar_t* kClassName = L"OptimizerUIClass";

struct Feature { const wchar_t* title; const wchar_t* description; };
struct Section { const wchar_t* title; const wchar_t* subtitle; std::vector<Feature> features; };
struct Accent { COLORREF color; COLORREF soft; COLORREF border; };

static std::vector<Section> gSections = {
    { L"الرئيسية", L"اختر نمطًا، واستعرض التغييرات قبل تشغيلها.", {
        {L"معاينة قبل التنفيذ", L"يعرض السكربت خطة التغييرات ويطلب تأكيدك قبل تعديل Windows."},
        {L"حماية النظام", L"لا يستهدف السكربت تعطيل Defender أو Windows Update أو الجدار الناري."},
        {L"نسخة استعادة", L"يحفظ إعدادات الخدمات والطاقة وبعض مفاتيح السجل في مجلد على سطح المكتب."},
        {L"تحكم بالحذف", L"حذف تطبيقات المتجر متوقف افتراضيًا ويحتاج تأكيدًا إضافيًا عند تفعيله."}
    }},
    { L"الأداء والمظهر", L"تحسينات للواجهة واستجابة الجهاز.", {
        {L"الرسوم المتحركة والمؤثرات", L"يمكن إيقاف الشفافية والرسوم المتحركة والظلال وبعض تأثيرات النوافذ."},
        {L"عناصر شريط المهام", L"يمكن إخفاء أزرار Widgets وChat وTask View وتغيير وجهة فتح Explorer."},
        {L"أولوية الألعاب", L"يضبط جدولة الوسائط المتعددة لمنح الألعاب أولوية أعلى."},
        {L"إغلاق التطبيقات العالقة", L"خيار اختياري لإغلاق أسرع؛ قد يؤدي فقدان عمل غير محفوظ."},
        {L"استهلاك Defender", L"يحد استخدام المعالج أثناء الفحص عند تفعيله؛ تظل الحماية الفورية مفعلة."},
        {L"تنظيف مؤقت", L"ينظف ملفات Temp ويحاول TRIM لقرص C ويفرغ ذاكرة DNS المؤقتة."}
    }},
    { L"الخصوصية", L"إعدادات الاقتراحات والتشخيص والميزات الخلفية.", {
        {L"التشخيص والتتبع", L"يوقف خدمات تشخيص محددة مثل DiagTrack وdmwappushservice."},
        {L"الإعلانات والاقتراحات", L"يقلل معرّف الإعلانات واقتراحات Start وبعض ميزات المستهلك."},
        {L"التطبيقات بالخلفية", L"يوقف ميزات خلفية محددة مثل Game DVR وCopilot وEdge Startup Boost."},
        {L"فهرسة البحث", L"تعطيل Windows Search اختياري؛ قد يجعل بحث Start أبطأ."},
        {L"إشعارات Windows", L"إيقاف كل التنبيهات المنبثقة خيار اختياري ومتوقف افتراضيًا."},
        {L"استثناءات Defender", L"استثناء مجلدات Minecraft خيار اختياري؛ استخدمه فقط إن كنت تثق بملفاتها."}
    }},
    { L"التطبيقات", L"إزالة التطبيقات اختيارية؛ راجع قائمة الحذف بعناية.", {
        {L"تطبيقات المتجر", L"قد يشمل الحذف Clipchamp وNews وWeather وSolitaire وPhone Link وCopilot."},
        {L"تأكيد إضافي", L"يتطلب حذف تطبيقات المتجر كتابة REMOVE بعد معاينة الخطة."},
        {L"برامج سطح المكتب", L"يمكن فتح قائمة اختيار للبرامج المثبتة؛ لا تُحذف إلا بعد تأكيد منفصل."},
        {L"تثبيت البرامج", L"يتضمن السكربت خيارًا لتثبيت متصفحات وأدوات عبر winget."},
        {L"تقرير InstallUtil", L"ينشئ تقريرًا إذا كانت أداة InstallUtil تعمل؛ لا يوقفها أو يحذفها."},
        {L"إزالة البرامج", L"قائمة البرامج المثبتة اختيارية ومتوقفة افتراضيًا في Balanced."}
    }},
    { L"بدء التشغيل", L"عناصر محددة بالاسم قد تتوقف عن التشغيل التلقائي.", {
        {L"تطبيقات مستهدفة", L"تشمل القائمة Discord وSpotify وSteam وTelegram وOneDrive وTeams وغيرها."},
        {L"تعديل القائمة", L"يمكنك إضافة الأنماط أو حذفها من $KillStartup أعلى ملف PowerShell."},
        {L"مهام التحديث", L"يعطّل مهام تحديث وقياس عن بُعد تطابق أسماء محددة."},
        {L"إعادة التشغيل", L"بعض تغييرات بدء التشغيل لا تظهر إلا بعد تسجيل الخروج أو إعادة التشغيل."}
    }},
    { L"الخدمات", L"الخدمات التي لا تستخدمها قد تعتمد عليها ميزة أخرى في جهازك.", {
        {L"خدمات تشخيص", L"قد يوقف DiagTrack وSysMain وRetailDemo وRemoteRegistry."},
        {L"خدمات اختيارية", L"يضبط خدمات مثل Fax وXbox وMaps إلى Manual عند توفرها."},
        {L"خدمات الشركات المصنّعة", L"يضبط بعض أدوات تحديث Dell وAdobe وJava وBrave إلى Manual."},
        {L"AnyDesk", L"ضبط خدمة AnyDesk على Manual خيار إضافي؛ يبقى تشغيلها اليدوي ممكنًا."},
        {L"محميّة من التعديل", L"يتجنب قائمة خدمات أساسية تشمل الشبكة وDefender وWindows Update."},
        {L"الاستعادة", L"يسجل أوضاع بدء الخدمات السابقة؛ ملف restore_settings يحاول إعادتها."}
    }},
    { L"الطاقة والصيانة", L"راجع أثر تغييرات الطاقة والتنظيف قبل الموافقة.", {
        {L"عند توصيل الشاحن", L"يمكن رفع استجابة المعالج وإيقاف سبات USB وPCIe والقرص على طاقة AC."},
        {L"البطارية", L"إعدادات الطاقة أثناء استخدام البطارية لا تُعدّل."},
        {L"الإسبات", L"تعطيل الإسبات خيار مستقل؛ يحرر مساحة تقارب حجم الذاكرة لكنه متوقف افتراضيًا."},
        {L"بدء التشغيل السريع", L"يعطّل Fast Startup حتى ينفذ Windows إيقاف تشغيل كاملًا."},
        {L"الصيانة", L"يشغّل TRIM ويمسح الملفات المؤقتة وذاكرة DNS عند إكمال التحسين."},
        {L"قائمة التغييرات", L"يمكن عرض أوضاع الخدمات والطاقة المحفوظة لاستعادتها لاحقًا."}
    }}
};

static const std::array<Accent, 7> gAccents = {{
    {RGB(76, 210, 167), RGB(27, 57, 55), RGB(58, 127, 111)},
    {RGB(72, 177, 235), RGB(27, 49, 68), RGB(58, 112, 151)},
    {RGB(116, 157, 245), RGB(34, 46, 72), RGB(75, 101, 157)},
    {RGB(244, 142, 99), RGB(64, 43, 40), RGB(155, 91, 68)},
    {RGB(239, 190, 83), RGB(61, 53, 37), RGB(145, 117, 58)},
    {RGB(183, 147, 231), RGB(53, 43, 66), RGB(115, 90, 149)},
    {RGB(141, 202, 102), RGB(42, 57, 41), RGB(92, 131, 70)}
}};

struct Profile { const wchar_t* name; const wchar_t* title; const wchar_t* detail; };
static const Profile gProfiles[] = {
    {L"Safe", L"آمن", L"تغييرات أقل؛ تبقى تغييرات النظام الأساسية موضحة في المعاينة."},
    {L"Balanced", L"متوازن", L"ملف الاستخدام العام؛ حذف التطبيقات غير مفعّل افتراضيًا."},
    {L"Aggressive", L"مكثّف", L"يتضمن تغييرات أكثر، مثل إيقاف فهرسة البحث وتنظيف التطبيقات."}
};

static HWND gWindow = nullptr;
static std::wstring gSelectedProfile = L"Balanced";
static int gSectionIndex = 0;
static int gHoverTarget = -1;
static std::array<float, 33> gHoverLevels{};
static BYTE gFade = 0;
static HFONT gFont = nullptr, gBoldFont = nullptr, gSmallFont = nullptr;
static constexpr UINT_PTR kAnimTimer = 1;

static COLORREF Mix(COLORREF a, COLORREF b, float t) {
    t = std::clamp(t, 0.0f, 1.0f);
    return RGB((int)(GetRValue(a) + (GetRValue(b) - GetRValue(a)) * t),
               (int)(GetGValue(a) + (GetGValue(b) - GetGValue(a)) * t),
               (int)(GetBValue(a) + (GetBValue(b) - GetBValue(a)) * t));
}

static void RoundRectFill(HDC dc, RECT r, int radius, COLORREF color, COLORREF border = RGB(48, 58, 75)) {
    HBRUSH brush = CreateSolidBrush(color);
    HPEN pen = CreatePen(PS_SOLID, 1, border);
    HGDIOBJ oldBrush = SelectObject(dc, brush), oldPen = SelectObject(dc, pen);
    RoundRect(dc, r.left, r.top, r.right, r.bottom, radius, radius);
    SelectObject(dc, oldBrush); SelectObject(dc, oldPen);
    DeleteObject(brush); DeleteObject(pen);
}

static void Text(HDC dc, const wchar_t* value, RECT r, COLORREF color, HFONT font,
                 UINT flags = DT_RIGHT | DT_RTLREADING | DT_VCENTER | DT_SINGLELINE) {
    SetBkMode(dc, TRANSPARENT); SetTextColor(dc, color);
    HGDIOBJ old = SelectObject(dc, font);
    DrawTextW(dc, value, -1, &r, flags | DT_NOPREFIX);
    SelectObject(dc, old);
}

static RECT GetNavRect(int i) { return RECT{22, 136 + i * 54, 198, 182 + i * 54}; }
static RECT GetProfileRect(int i, int mainX, int mainW) {
    int gap = 12, w = (mainW - 2 * gap) / 3;
    return RECT{mainX + i * (w + gap), 184, mainX + i * (w + gap) + w, 270};
}
static RECT GetRunRect(int clientW, int clientH) { return RECT{clientW - 228, clientH - 70, clientW - 28, clientH - 22}; }
static RECT GetDownloadsRect(int clientW, int clientH) { return RECT{clientW - 430, clientH - 70, clientW - 240, clientH - 22}; }
static RECT GetAdvancedRect(int clientW, int clientH) { return RECT{clientW - 635, clientH - 70, clientW - 445, clientH - 22}; }

static int HitTest(POINT p, int w, int h) {
    for (int i = 0; i < (int)gSections.size(); ++i) { RECT r = GetNavRect(i); if (PtInRect(&r, p)) return i; }
    int mainX = 230, mainW = w - mainX - 26;
    if (gSectionIndex == 0) for (int i = 0; i < 3; ++i) { RECT r = GetProfileRect(i, mainX, mainW); if (PtInRect(&r, p)) return 20 + i; }
    RECT run = GetRunRect(w, h); if (PtInRect(&run, p)) return 30;
    RECT downloads = GetDownloadsRect(w, h); if (PtInRect(&downloads, p)) return 31;
    RECT advanced = GetAdvancedRect(w, h); if (PtInRect(&advanced, p)) return 32;
    return -1;
}

static void DrawCard(HDC dc, RECT r, const Feature& feature, int cardIndex, const Accent& accent) {
    COLORREF surface = cardIndex % 2 ? RGB(27, 35, 49) : RGB(25, 33, 47);
    RoundRectFill(dc, r, 14, Mix(surface, accent.soft, 0.24f), Mix(RGB(43, 55, 73), accent.border, 0.38f));
    RECT marker{r.right - 5, r.top + 15, r.right - 2, r.bottom - 15};
    HBRUSH markerBrush = CreateSolidBrush(accent.color);
    FillRect(dc, &marker, markerBrush); DeleteObject(markerBrush);
    RECT title{r.left + 18, r.top + 13, r.right - 21, r.top + 44};
    Text(dc, feature.title, title, RGB(241, 246, 255), gBoldFont);
    RECT desc{r.left + 18, r.top + 48, r.right - 22, r.bottom - 12};
    Text(dc, feature.description, desc, RGB(166, 180, 200), gSmallFont,
         DT_RIGHT | DT_RTLREADING | DT_TOP | DT_WORDBREAK);
}

static void Paint(HDC target, RECT client) {
    int w = client.right, h = client.bottom;
    HDC buffer = CreateCompatibleDC(target);
    HBITMAP bitmap = CreateCompatibleBitmap(target, w, h);
    HGDIOBJ oldBitmap = SelectObject(buffer, bitmap);
    for (int y = 0; y < h; ++y) {
        float t = h > 1 ? (float)y / (h - 1) : 0.0f;
        RECT band{0, y, w, y + 1};
        HBRUSH b = CreateSolidBrush(Mix(RGB(13, 19, 31), RGB(17, 27, 42), t));
        FillRect(buffer, &band, b); DeleteObject(b);
    }
    int mainX = 230, mainW = w - mainX - 26;
    const Accent& accent = gAccents[gSectionIndex];

    RECT side{12, 12, 210, h - 12};
    RoundRectFill(buffer, side, 20, RGB(20, 29, 43), RGB(37, 49, 67));
    RECT brand{31, 30, 190, 61};
    Text(buffer, L"مُحسِّن Windows", brand, RGB(245, 248, 255), gBoldFont);
    RECT subBrand{31, 63, 190, 88};
    Text(buffer, L"لوحة التعديلات", subBrand, RGB(117, 145, 177), gSmallFont);
    for (int i = 0; i < (int)gSections.size(); ++i) {
        RECT r = GetNavRect(i);
        bool selected = i == gSectionIndex;
        float hover = gHoverLevels[i];
        COLORREF base = selected ? accent.soft : RGB(20, 29, 43);
        COLORREF over = selected ? Mix(accent.soft, accent.color, 0.22f) : RGB(34, 47, 65);
        if (selected || hover > 0.01f) RoundRectFill(buffer, r, 11, Mix(base, over, hover), selected ? accent.border : RGB(43, 58, 78));
        if (selected) {
            RECT accent{r.right - 4, r.top + 8, r.right - 2, r.bottom - 8};
            HBRUSH b = CreateSolidBrush(gAccents[gSectionIndex].color); FillRect(buffer, &accent, b); DeleteObject(b);
        }
        RECT label{r.left + 10, r.top + 2, r.right - 15, r.bottom - 2};
        Text(buffer, gSections[i].title, label, selected ? RGB(255,255,255) : RGB(177,191,209), selected ? gBoldFont : gFont);
    }
    RECT sideNote{32, h - 75, 190, h - 34};
    Text(buffer, L"اقرأ الخطة قبل\nالموافقة على التنفيذ", sideNote, RGB(122, 144, 169), gSmallFont,
         DT_RIGHT | DT_RTLREADING | DT_WORDBREAK | DT_VCENTER);

    RECT headerTitle{mainX, 24, w - 28, 66};
    Text(buffer, gSections[gSectionIndex].title, headerTitle, accent.color, gBoldFont,
         DT_RIGHT | DT_RTLREADING | DT_VCENTER | DT_SINGLELINE);
    RECT headerSub{mainX, 68, w - 28, 96};
    Text(buffer, gSections[gSectionIndex].subtitle, headerSub, RGB(145, 165, 190), gFont,
         DT_RIGHT | DT_RTLREADING | DT_VCENTER | DT_SINGLELINE);

    int contentTop = 112, contentBottom = h - 100;
    if (gSectionIndex == 0) {
        RECT profileLabel{mainX, 112, w - 28, 145};
        Text(buffer, L"ملف التحسين", profileLabel, RGB(198, 214, 234), gBoldFont);
        int selectedProfile = gSelectedProfile == L"Safe" ? 0 : gSelectedProfile == L"Aggressive" ? 2 : 1;
        for (int i = 0; i < 3; ++i) {
            RECT r = GetProfileRect(i, mainX, mainW);
            bool selected = i == selectedProfile;
            float hover = gHoverLevels[20 + i];
            COLORREF base = selected ? accent.soft : RGB(25, 33, 47);
            COLORREF over = selected ? Mix(accent.soft, accent.color, 0.2f) : RGB(36, 52, 70);
            RoundRectFill(buffer, r, 14, Mix(base, over, hover), selected ? accent.border : RGB(43, 55, 73));
            RECT name{r.left + 10, r.top + 10, r.right - 14, r.top + 38};
            Text(buffer, gProfiles[i].title, name, RGB(240, 247, 250), gBoldFont);
            RECT desc{r.left + 12, r.top + 42, r.right - 14, r.bottom - 8};
            Text(buffer, gProfiles[i].detail, desc, RGB(164, 185, 199), gSmallFont,
                 DT_RIGHT | DT_RTLREADING | DT_TOP | DT_WORDBREAK);
        }
        RECT info{mainX, 286, w - 28, 325};
        Text(buffer, L"ماذا يفعل السكربت؟", info, RGB(198, 214, 234), gBoldFont);
        contentTop = 330;
    }

    const auto& features = gSections[gSectionIndex].features;
    int gap = 14;
    int cardW = (mainW - gap) / 2;
    int available = contentBottom - contentTop;
    int rows = ((int)features.size() + 1) / 2;
    int cardH = (available - gap * (rows - 1)) / rows;
    for (int i = 0; i < (int)features.size(); ++i) {
        int col = i % 2, row = i / 2;
        RECT r{mainX + col * (cardW + gap), contentTop + row * (cardH + gap),
               mainX + col * (cardW + gap) + cardW, contentTop + row * (cardH + gap) + cardH};
        DrawCard(buffer, r, features[i], i, accent);
    }

    RECT footer{mainX, h - 75, w - 650, h - 23};
    Text(buffer, L"راجع الإعدادات والخطة قبل التطبيق.", footer,
         RGB(137, 158, 184), gSmallFont, DT_RIGHT | DT_RTLREADING | DT_VCENTER | DT_WORDBREAK);
    RECT advanced = GetAdvancedRect(w, h);
    float advancedHover = gHoverLevels[32];
    RoundRectFill(buffer, advanced, 13, Mix(RGB(61, 83, 108), RGB(83, 112, 143), advancedHover), RGB(107, 148, 183));
    RECT advancedText{advanced.left + 6, advanced.top + 1, advanced.right - 6, advanced.bottom - 1};
    Text(buffer, L"تويكات متقدمة", advancedText, RGB(255, 255, 255), gBoldFont);
    RECT downloads = GetDownloadsRect(w, h);
    float downloadsHover = gHoverLevels[31];
    RoundRectFill(buffer, downloads, 13, Mix(RGB(38, 104, 145), RGB(52, 137, 181), downloadsHover), RGB(87, 174, 211));
    RECT downloadsText{downloads.left + 6, downloads.top + 1, downloads.right - 6, downloads.bottom - 1};
    Text(buffer, L"التطبيقات والتعريفات", downloadsText, RGB(255, 255, 255), gBoldFont);
    RECT run = GetRunRect(w, h);
    float runHover = gHoverLevels[30];
    RoundRectFill(buffer, run, 13, Mix(RGB(24, 146, 124), RGB(44, 184, 153), runHover), RGB(66, 211, 178));
    RECT runText{run.left + 8, run.top + 1, run.right - 8, run.bottom - 1};
    Text(buffer, L"تشغيل المُحسِّن  ←", runText, RGB(255,255,255), gBoldFont);

    BitBlt(target, 0, 0, w, h, buffer, 0, 0, SRCCOPY);
    SelectObject(buffer, oldBitmap); DeleteObject(bitmap); DeleteDC(buffer);
}

static void LaunchScript(const wchar_t* launchMode) {
    wchar_t module[MAX_PATH] = {};
    DWORD len = GetModuleFileNameW(nullptr, module, MAX_PATH);
    if (!len || len >= MAX_PATH) {
        MessageBoxW(gWindow, L"تعذر تحديد مجلد البرنامج.", L"خطأ", MB_ICONERROR | MB_OK);
        return;
    }
    std::wstring dir(module);
    size_t slash = dir.find_last_of(L"\\/");
    dir = slash == std::wstring::npos ? L"." : dir.substr(0, slash);
    std::wstring script = dir + L"\\full_optimize.ps1";
    if (GetFileAttributesW(script.c_str()) == INVALID_FILE_ATTRIBUTES) {
        MessageBoxW(gWindow, L"لم أجد full_optimize.ps1 بجانب البرنامج. ضع الملفين في المجلد نفسه.", L"الملف غير موجود", MB_ICONWARNING | MB_OK);
        return;
    }
    std::wstring args = L"-NoProfile -ExecutionPolicy Bypass -File \"" + script + L"\" -LaunchProfile \"" + gSelectedProfile + L"\" -LaunchMode \"" + launchMode + L"\"";
    SHELLEXECUTEINFOW info{};
    info.cbSize = sizeof(info); info.fMask = SEE_MASK_NOCLOSEPROCESS;
    info.lpVerb = L"runas"; info.lpFile = L"powershell.exe"; info.lpParameters = args.c_str();
    info.lpDirectory = dir.c_str(); info.nShow = SW_SHOWNORMAL;
    if (!ShellExecuteExW(&info)) {
        DWORD error = GetLastError();
        if (error != ERROR_CANCELLED) {
            wchar_t msg[160]; swprintf_s(msg, L"تعذر تشغيل PowerShell (رمز الخطأ %lu).", error);
            MessageBoxW(gWindow, msg, L"فشل التشغيل", MB_ICONERROR | MB_OK);
        }
    }
    if (info.hProcess) CloseHandle(info.hProcess);
}

static LRESULT CALLBACK WindowProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_CREATE: {
        gWindow = hwnd;
        gFont = CreateFontW(18,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH|FF_DONTCARE,L"Segoe UI");
        gBoldFont = CreateFontW(20,0,0,0,FW_SEMIBOLD,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH|FF_DONTCARE,L"Segoe UI");
        gSmallFont = CreateFontW(15,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH|FF_DONTCARE,L"Segoe UI");
        SetLayeredWindowAttributes(hwnd, 0, 0, LWA_ALPHA);
        SetTimer(hwnd, kAnimTimer, 16, nullptr);
        return 0;
    }
    case WM_TIMER:
        if (wp == kAnimTimer) {
            if (gFade < 255) { gFade = (BYTE)(std::min)(255, (int)gFade + 22); SetLayeredWindowAttributes(hwnd, 0, gFade, LWA_ALPHA); }
            bool changed = false;
            for (int i = 0; i < (int)gHoverLevels.size(); ++i) {
                float goal = i == gHoverTarget ? 1.0f : 0.0f;
                float current = gHoverLevels[i];
                float next = current + (goal - current) * 0.28f;
                if (std::abs(next - current) > 0.01f) { gHoverLevels[i] = next; changed = true; }
                else if (current != goal) { gHoverLevels[i] = goal; changed = true; }
            }
            if (changed) InvalidateRect(hwnd, nullptr, FALSE);
            else if (gFade >= 255) KillTimer(hwnd, kAnimTimer);
        }
        return 0;
    case WM_MOUSEMOVE: {
        POINT p{GET_X_LPARAM(lp), GET_Y_LPARAM(lp)}; RECT rc{}; GetClientRect(hwnd, &rc);
        int hit = HitTest(p, rc.right, rc.bottom);
        if (hit != gHoverTarget) { gHoverTarget = hit; SetTimer(hwnd, kAnimTimer, 16, nullptr); InvalidateRect(hwnd, nullptr, FALSE); }
        TRACKMOUSEEVENT tme{sizeof(tme), TME_LEAVE, hwnd, 0}; TrackMouseEvent(&tme);
        return 0;
    }
    case WM_MOUSELEAVE:
        gHoverTarget = -1; SetTimer(hwnd, kAnimTimer, 16, nullptr); InvalidateRect(hwnd, nullptr, FALSE); return 0;
    case WM_LBUTTONDOWN: {
        POINT p{GET_X_LPARAM(lp), GET_Y_LPARAM(lp)}; RECT rc{}; GetClientRect(hwnd, &rc);
        int hit = HitTest(p, rc.right, rc.bottom);
        if (hit >= 0 && hit < (int)gSections.size()) { gSectionIndex = hit; InvalidateRect(hwnd, nullptr, FALSE); }
        else if (hit >= 20 && hit <= 22) { gSelectedProfile = gProfiles[hit - 20].name; InvalidateRect(hwnd, nullptr, FALSE); }
        else if (hit == 30) LaunchScript(L"Optimize");
        else if (hit == 31) LaunchScript(L"Downloads");
        else if (hit == 32) LaunchScript(L"AdvancedTweaks");
        return 0;
    }
    case WM_PAINT: {
        PAINTSTRUCT ps{}; HDC dc = BeginPaint(hwnd, &ps); RECT rc{}; GetClientRect(hwnd, &rc); Paint(dc, rc); EndPaint(hwnd, &ps); return 0;
    }
    case WM_ERASEBKGND: return 1;
    case WM_DESTROY:
        KillTimer(hwnd, kAnimTimer);
        if (gFont) DeleteObject(gFont); if (gBoldFont) DeleteObject(gBoldFont); if (gSmallFont) DeleteObject(gSmallFont);
        PostQuitMessage(0); return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int show) {
    WNDCLASSEXW wc{}; wc.cbSize = sizeof(wc); wc.lpfnWndProc = WindowProc; wc.hInstance = instance;
    wc.hCursor = LoadCursorW(nullptr, IDC_HAND); wc.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    wc.lpszClassName = kClassName; wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    if (!RegisterClassExW(&wc)) return 1;
    HWND hwnd = CreateWindowExW(WS_EX_LAYERED, kClassName, L"مُحسِّن Windows",
        WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
        CW_USEDEFAULT, CW_USEDEFAULT, 1120, 825, nullptr, nullptr, instance, nullptr);
    if (!hwnd) return 1;
    ShowWindow(hwnd, show); UpdateWindow(hwnd);
    MSG message{}; while (GetMessageW(&message, nullptr, 0, 0) > 0) { TranslateMessage(&message); DispatchMessageW(&message); }
    return (int)message.wParam;
}
