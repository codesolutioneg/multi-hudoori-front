# Hudoori Multi Dashboard — Work State

**Repo:** `/root/hudoori-multi/dashboard`  
**Scope:** Flutter multi-company UI (login company code, Super Admin company switcher).  
**Reference (read-only):** `/root/hodouri/biotime_web_dashboard-dev`  
**Do not log backend work here.**

## Rules
- Copy UI flows/logic from Dev reference as-is; ask before changing business behaviour.
- Never put secrets here.
- Never touch `/root/hodouri/*`.

## Daily log

### 2026-10-05
- **Auto**: Mobile matches web dashboard UX — drawer-only (removed bottom nav), same `/me` menus + `/hr` routes; Platform Admin gets web-only message; HR home → `/hr/dashboard` with entitlement-filtered KPIs/shortcuts. **MULTI**.
- **Auto**: Settings always visible for HR managers (no longer gated by `advanced_permissions`); inside Settings hide Odoo/advances/payroll/tips/team sections by entitlement. Access-denied shows friendly feature name (not raw key). Backend menu map + client maps updated; rebuilt web + restarted backend/dashboard. **MULTI**.
- **Auto**: Hide Home shortcuts + KPI tiles (and related sections) when plan feature is off — uses `/me` entitlements with menus fallback so UI matches sidebar. Deep links still hit `/access-denied`. Rebuilt web + restarted `hudoori-multi-dashboard`. **MULTI**.
- **Auto**: Super Admin company switcher reloads Users / audit-permission pages / create-user locations when `activeCompanyId` changes; users subtitle shows company name; `COMPANY_CONTEXT_REQUIRED` friendly error. Main system: plan entitlements in `AuthFeatures`, `/access-denied` for feature/role blocks, Home quick-actions + shell nav check entitlements, API 403 parses `FEATURE_DISABLED`. Rebuilt web + restarted `hudoori-multi-dashboard`. **MULTI**.

### 2026-10-01
- **Auto**: Users page — زر «إعادة إرسال الميل» على كارت المستخدم؛ reset باسورد + إرسال الميل مع companyCode. **MULTI**.
- **Auto**: طلبات المبيعات — UI محسّن + نسخ حقول + تعديل قبل الموافقة (الحصة من عدد الموظفين المعدّل) + ميل يتضمن التفاصيل + تصدير CSV/Excel حسب الفلتر. الباقات — تعديل كل سطر في الكارت (عنوان/وصف/سعر/مميزات AR+EN) وينعكس على الـlanding بدون كسر `/emp/mo`. إصلاح `mail.service` و`app_router`. **MULTI**.
- **Auto**: إصلاح صفحة الباقات (وطلبات المبيعات): `AppPageScaffold(scrollable: false)` حتى يظهر `Expanded`+القائمة بدل شاشة فاضية. **MULTI**.
- **Auto**: إصلاح كروت الأسعار — إيقاف overwrite من API على الـHTML الثابت. تحسين مودال Contact sales (ثنائي اللغة AR/EN). View Demo يفتح `/sign-in?demo=1` مع تعبئة company/login/password تلقائياً. **MULTI**.
- **Auto**: Landing على `https://hr.hudoori.code-solution.org/landing/` (static تحت `/var/www/hudoori-site/landing/`؛ nginx في `hudoori-multi-dashboard`). أُوقف `:8090` العام (تعارض reload + CORS). CORS للـAPI يعتمد أصل `https://hr.hudoori.code-solution.org`. **MULTI**.
- **Auto**: Super Admin — «طلبات المبيعات» (approve/reject + confirm) و«باقات الاشتراك» (edit, publish/draft, no delete); API client + nav/routes. Landing page: View Demo (HR tab + credentials txt), sales modal, dynamic plans from API. Rebuilt web, restarted `hudoori-multi-dashboard`. **MULTI**.

### 2026-09-30
- **Auto**: SaaS seats UI — Super Admin companies page: create dialog requires max employees / max users, «تعديل الحصة» dialog (empty = unlimited), list shows `used / max` (orange when full). HR employees page shows a banner when employee seats are full. `friendlyApiError` handles `EMPLOYEE_QUOTA_EXCEEDED` / `USER_QUOTA_EXCEEDED` (server Arabic message, l10n fallback ar/en). Rebuilt prod, restarted `hudoori-multi-dashboard`; verified in browser on `hr.` (list quota, dialog, banner on acme, then reset to unlimited). **MULTI**.

### 2026-09-28
- **Auto**: تقرير البصمات: عند توقف/عدم ضبط BioTime يُبنى من البصمات المخزّنة + رسالة ودّية بدل Invalid URL. **MULTI**.
- **Auto**: Ported prod UI logic into Multi: monthly reports dialog, deductions/advances/payroll/audit/shift-grid pages, `long_advance_filters`, API client (monthlyReports + deleteBulk + approveConflicts + confirm-branch dateFrom/To); preserved Multi shells/company switcher. Flutter analyze 0 errors; web rebuild for `hr.hudoori` → `:8083`. **MULTI**.

### 2026-09-15
- **Auto**: Ported prod UI: `ListPickerField` vertical scrollbar; loan-import review H/V scroll + drag/Shift+wheel; shift-grid list pre-selects/tints monthly merge grids. **MULTI**.
- **Auto**: Android release needs `INTERNET` in main `AndroidManifest` (was only debug/profile). Verified `flutter test` 88/88; analyze 0 errors. Multi API not running on :3003 (hr-api down) — deploy pending user OK. **MULTI**.
- **Auto**: Ported loan-import «معتمد» field formatting (`formatMoneyField` / `parseMoney`) from single-company prod. **MULTI**.

### 2026-09-13
- **Auto**: Scaffold — copied Dev dashboard into `/root/hudoori-multi/dashboard` (excluded build, .dart_tool, .git). Fresh git repo, no remotes. **MULTI**.
- **Auto**: Domains — dashboard default API `https://hr-api.hudoori.code-solution.org`; frontend host `https://hr.hudoori.code-solution.org`. **MULTI**.
- **Auto**: Super Admin UI — صفحة الشركات + مبدّل الشركة في الشريط؛ عناصر Users/Settings تُقفل حتى اختيار شركة؛ زر الإعدادات يختار الشركة ثم يفتح HR settings. **MULTI**.
- **Auto**: بناء web production لـ `https://hr.hudoori.code-solution.org` (API `hr-api`) وخدمة static على `:8083`. **MULTI**.
- **Auto**: إعدادات HR لبصمة الموقع لكل فرع + شاشة `/my/location-punch` + عرض اسم الشركة في الـ shell؛ geolocator + صلاحيات Android/iOS. **MULTI**.
- **Auto**: حقل نطاق البصمة بالمتر قابل للضبط بالكامل (10/50/…) مع اختصارات سريعة في إعدادات الفرع. **MULTI**.
- **Auto**: إعادة بناء ونشر web لـ `hr.hudoori…` لإظهار قسم «بصمة الموقع (الفروع)» في الإعدادات. **MULTI**.
- **Auto**: Initial commit + `origin` → `codesolutioneg/multi-hudoori-front` (local `main`). Push blocked: token user has pull-only (403). **MULTI**.
- **Auto**: Pushed `main` to `https://github.com/codesolutioneg/multi-hudoori-front.git`. **MULTI**.
