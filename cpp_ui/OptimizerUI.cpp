#define UNICODE
#define _UNICODE

#include <windows.h>
#include <commctrl.h>
#include <string>
#include <vector>

#pragma comment(lib, "Comctl32.lib")

const wchar_t* gWindowClassName = L"OptimizerUIClass";
const wchar_t* gSelectedPreset = L"Balanced";

struct PresetOption {
    const wchar_t* name;
    const wchar_t* description;
};

static const std::vector<PresetOption> gPresets = {
    { L"Safe", L"Low-risk profile for daily use with minimal changes and maximum stability." },
    { L"Balanced", L"Recommended profile with a practical balance between speed and safety." },
    { L"Aggressive", L"Performance-focused profile with more aggressive cleanup and visual tuning." },
    { L"Custom", L"Use the custom settings defined in the PowerShell script file." }
};

HINSTANCE g_hInst = nullptr;
HWND gDescriptionLabel = nullptr;
HWND gStatusLabel = nullptr;
HWND gFeatureList = nullptr;
HWND gTabControl = nullptr;

std::wstring GetScriptDirectory() {
    wchar_t path[MAX_PATH] = { 0 };
    DWORD len = GetModuleFileNameW(nullptr, path, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) {
        return L".";
    }

    std::wstring full(path);
    size_t pos = full.find_last_of(L"\\/");
    if (pos == std::wstring::npos) {
        return L".";
    }
    return full.substr(0, pos);
}

void UpdateDescription(HWND hWnd, const wchar_t* presetName) {
    std::wstring desc = L"Select a profile to learn more.";
    for (const auto& preset : gPresets) {
        if (_wcsicmp(preset.name, presetName) == 0) {
            desc = preset.description;
            break;
        }
    }

    SetWindowTextW(gDescriptionLabel, desc.c_str());
    SetWindowTextW(hWnd, (std::wstring(L"Windows Optimizer - ") + presetName).c_str());
}

void PopulateFeatureList(int tabIndex) {
    if (!gFeatureList) {
        return;
    }

    SendMessageW(gFeatureList, LB_RESETCONTENT, 0, 0);

    switch (tabIndex) {
    case 0:
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Safe profile");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Balanced profile");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Aggressive profile");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Custom profile");
        SetWindowTextW(gDescriptionLabel, L"Choose the best setup for your system: stable, balanced, or aggressive tuning.");
        break;
    case 1:
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Add performance tweaks");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Reduce visual effects");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Optimize power plan");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Clean temp files and caches");
        SetWindowTextW(gDescriptionLabel, L"Performance features focus on speed, responsiveness, and lower background activity without disabling core protections.");
        break;
    case 2:
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Install Chrome");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Install Brave");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Install Firefox");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Install 7-Zip");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Install VLC");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Install PowerToys");
        SetWindowTextW(gDescriptionLabel, L"Useful software can be installed quickly with winget, including browsers, utilities, archive tools, and productivity apps.");
        break;
    case 3:
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Disable Discord startup");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Disable Steam startup");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Disable Spotify startup");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Disable Teams startup");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Disable OneDrive startup");
        SetWindowTextW(gDescriptionLabel, L"Startup management helps stop unnecessary programs from waking up at logon and slowing your system down.");
        break;
    case 4:
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"SysMain");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"DiagTrack");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"WSearch");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Fax");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"MapsBroker");
        SendMessageW(gFeatureList, LB_ADDSTRING, 0, (LPARAM)L"Xbox services");
        SetWindowTextW(gDescriptionLabel, L"Service tuning allows you to reduce background noise and disable low-value services while preserving core Windows protections.");
        break;
    default:
        SetWindowTextW(gDescriptionLabel, L"Ready.");
        break;
    }
}

void RunOptimizerScript() {
    std::wstring dir = GetScriptDirectory();
    std::wstring scriptPath = dir + L"\\full_optimize.ps1";

    std::wstring params = L"-NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + L"\"";

    SHELLEXECUTEINFOW sei = { 0 };
    sei.cbSize = sizeof(sei);
    sei.lpVerb = L"runas";
    sei.lpFile = L"powershell.exe";
    sei.lpParameters = params.c_str();
    sei.lpDirectory = dir.c_str();
    sei.nShow = SW_SHOWNORMAL;

    if (ShellExecuteExW(&sei)) {
        SetWindowTextW(gStatusLabel, L"PowerShell optimizer started with Administrator privileges.");
    } else {
        DWORD err = GetLastError();
        wchar_t msg[256] = { 0 };
        swprintf_s(msg, L"Failed to start optimizer. Error: %lu", err);
        SetWindowTextW(gStatusLabel, msg);
    }
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_CREATE: {
        INITCOMMONCONTROLSEX icex = { 0 };
        icex.dwSize = sizeof(iex);
        icex.dwICC = ICC_TAB_CLASSES | ICC_STANDARD_CLASSES;
        InitCommonControlsEx(&iex);

        HFONT hFont = CreateFontW(18, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
                                  DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                                  CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY,
                                  DEFAULT_PITCH | FF_DMOD, L"Segoe UI");

        CreateWindowW(L"STATIC", L"Windows Optimizer",
                      WS_CHILD | WS_VISIBLE | SS_LEFT,
                      24, 18, 260, 36, hWnd, nullptr, g_hInst, nullptr);

        gTabControl = CreateWindowExW(0, L"SysTabControl32", NULL,
                                     WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS,
                                     20, 54, 660, 270, hWnd, (HMENU)100, g_hInst, NULL);

        TCITEMW tabItem = { 0 };
        tabItem.mask = TCIF_TEXT;

        tabItem.pszText = L"الرئيسية";
        TabCtrl_InsertItem(gTabControl, 0, &tabItem);
        tabItem.pszText = L"الأداء";
        TabCtrl_InsertItem(gTabControl, 1, &tabItem);
        tabItem.pszText = L"التطبيقات";
        TabCtrl_InsertItem(gTabControl, 2, &tabItem);
        tabItem.pszText = L"Startup";
        TabCtrl_InsertItem(gTabControl, 3, &tabItem);
        tabItem.pszText = L"الخدمات";
        TabCtrl_InsertItem(gTabControl, 4, &tabItem);

        gFeatureList = CreateWindowExW(0, L"LISTBOX", NULL,
                                     WS_CHILD | WS_VISIBLE | WS_VSCROLL | LBS_NOTIFY | LBS_HASSTRINGS,
                                     32, 90, 300, 160, hWnd, (HMENU)200, g_hInst, NULL);

        gDescriptionLabel = CreateWindowExW(0, L"STATIC", L"Select a profile to learn more.",
                                            WS_CHILD | WS_VISIBLE | SS_LEFT | SS_NOTIFY,
                                            360, 90, 290, 160, hWnd, nullptr, g_hInst, nullptr);

        HWND btnRun = CreateWindowExW(0, L"BUTTON", L"Run optimizer",
                                      WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                                      32, 270, 180, 40, hWnd, (HMENU)300, g_hInst, nullptr);

        HWND btnClose = CreateWindowExW(0, L"BUTTON", L"Close",
                                       WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                                       232, 270, 120, 40, hWnd, (HMENU)301, g_hInst, nullptr);

        gStatusLabel = CreateWindowExW(0, L"STATIC", L"Ready.",
                                      WS_CHILD | WS_VISIBLE | SS_LEFT,
                                      24, 330, 620, 32, hWnd, nullptr, g_hInst, nullptr);

        SendMessageW(gDescriptionLabel, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(gStatusLabel, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(gFeatureList, WM_SETFONT, (WPARAM)hFont, TRUE);

        TabCtrl_SetCurSel(gTabControl, 0);
        PopulateFeatureList(0);
        UpdateDescription(hWnd, gSelectedPreset);
        return 0;
    }
    case WM_NOTIFY: {
        if (((LPNMHDR)lParam)->code == TCN_SELCHANGE && (HWND)((LPNMHDR)lParam)->hwndFrom == gTabControl) {
            int idx = TabCtrl_GetCurSel(gTabControl);
            PopulateFeatureList(idx);
        }
        return 0;
    }
    case WM_COMMAND: {
        if (LOWORD(wParam) == 200 && HIWORD(wParam) == LBN_SELCHANGE) {
            int idx = (int)SendMessageW(gFeatureList, LB_GETCURSEL, 0, 0);
            if (idx >= 0) {
                wchar_t text[256] = { 0 };
                SendMessageW(gFeatureList, LB_GETTEXT, idx, (LPARAM)text);
                SetWindowTextW(gDescriptionLabel, text);
            }
        }

        if (LOWORD(wParam) == 300 && HIWORD(wParam) == BN_CLICKED) {
            RunOptimizerScript();
        }

        if (LOWORD(wParam) == 301 && HIWORD(wParam) == BN_CLICKED) {
            PostQuitMessage(0);
        }
        return 0;
    }
    case WM_CTLCOLORSTATIC: {
        HDC hdc = (HDC)wParam;
        SetBkColor(hdc, RGB(18, 18, 22));
        SetTextColor(hdc, RGB(240, 240, 240));
        return (LRESULT)GetStockObject(DC_BRUSH);
    }
    case WM_ERASEBKGND: {
        RECT rc;
        GetClientRect(hWnd, &rc);
        HBRUSH brush = CreateSolidBrush(RGB(18, 18, 22));
        FillRect((HDC)wParam, &rc, brush);
        DeleteObject(brush);
        return 1;
    }
    case WM_CLOSE:
        DestroyWindow(hWnd);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcW(hWnd, message, wParam, lParam);
    }
    return 0;
}

ATOM RegisterWindowClass(HINSTANCE hInstance) {
    WNDCLASSEXW wc = { 0 };
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.lpszClassName = gWindowClassName;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.hIcon = LoadIcon(nullptr, IDI_APPLICATION);
    return RegisterClassExW(&wc);
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, PWSTR, int) {
    g_hInst = hInstance;
    RegisterWindowClass(hInstance);

    HWND hWnd = CreateWindowExW(
        0,
        gWindowClassName,
        L"Windows Optimizer",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        720, 430,
        nullptr, nullptr, hInstance, nullptr);

    if (!hWnd) {
        return 1;
    }

    ShowWindow(hWnd, SW_SHOWNORMAL);
    UpdateWindow(hWnd);

    MSG msg = {};
    while (GetMessageW(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    return (int)msg.wParam;
}
