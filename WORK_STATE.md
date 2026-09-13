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
