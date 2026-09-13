import 'package:equatable/equatable.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class BioTimeMenuItem extends Equatable {
  const BioTimeMenuItem({required this.id, required this.name, required this.icon, required this.route});
  final String id;
  final String name;
  final String icon;
  final String route;

  factory BioTimeMenuItem.fromJson(Map<String, dynamic> json) => BioTimeMenuItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        icon: json['icon']?.toString() ?? 'dashboard',
        route: json['route']?.toString() ?? '/dashboard',
      );

  @override
  List<Object?> get props => [id];
}

class BioTimeUser extends Equatable {
  const BioTimeUser({
    required this.id,
    required this.name,
    this.email = '',
    this.role = '',
    this.isPlatformAdmin = false,
    this.locationId,
    this.locationName,
  });
  final String id;
  final String name;
  final String email;
  final String role;
  final bool isPlatformAdmin;
  final String? locationId;
  final String? locationName;

  factory BioTimeUser.fromJson(Map<String, dynamic> json) => BioTimeUser(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        isPlatformAdmin: json['isPlatformAdmin'] == true,
        locationId: json['locationId']?.toString(),
        locationName: json['locationName']?.toString(),
      );

  @override
  List<Object?> get props => [id, isPlatformAdmin, locationId];
}

class BioTimeRoles extends Equatable {
  const BioTimeRoles({
    this.isEmployee = false,
    this.isHrUser = false,
    this.isHrManager = false,
    this.isHrSupervisor = false,
    this.isBranchManager = false,
    this.isDeviceManager = false,
    this.isSystemAdmin = false,
    this.isPlatformAdmin = false,
  });
  final bool isEmployee;
  final bool isHrUser;
  final bool isHrManager;
  final bool isHrSupervisor;
  final bool isBranchManager;
  final bool isDeviceManager;
  final bool isSystemAdmin;
  final bool isPlatformAdmin;

  bool get isHrStaff => isHrUser || isHrManager;
  bool get isBranchStaff => isBranchManager || isHrStaff;

  factory BioTimeRoles.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BioTimeRoles();
    return BioTimeRoles(
      isEmployee: json['isEmployee'] == true,
      isHrUser: json['isHrUser'] == true,
      isHrManager: json['isHrManager'] == true,
      isHrSupervisor: json['isHrSupervisor'] == true,
      isBranchManager: json['isBranchManager'] == true,
      isDeviceManager: json['isDeviceManager'] == true,
      isSystemAdmin: json['isSystemAdmin'] == true,
      isPlatformAdmin: json['isPlatformAdmin'] == true,
    );
  }

  @override
  List<Object?> get props => [isEmployee, isHrUser, isHrManager, isHrSupervisor, isBranchManager, isDeviceManager, isSystemAdmin, isPlatformAdmin];
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.token,
    this.user,
    this.employeeName = '',
    this.employeeCode = '',
    this.roles = const BioTimeRoles(),
    this.menus = const [],
    this.features = const AuthFeatures(),
    this.errorMessage,
    this.profileWarning,
    this.isPlatformAdmin = false,
    this.activeCompanyId,
    this.activeCompanyName,
    this.activeCompanyCode,
  });

  final AuthStatus status;
  final String? token;
  final BioTimeUser? user;
  final String employeeName;
  final String employeeCode;
  final BioTimeRoles roles;
  final List<BioTimeMenuItem> menus;
  final AuthFeatures features;
  final String? errorMessage;
  final String? profileWarning;
  final bool isPlatformAdmin;
  final String? activeCompanyId;
  final String? activeCompanyName;
  final String? activeCompanyCode;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  bool get hasActiveCompany =>
      activeCompanyId != null && activeCompanyId!.trim().isNotEmpty;

  bool get canViewAudit =>
      isPlatformAdmin || roles.isPlatformAdmin || features.auditLog;

  bool get canViewAssistant =>
      isPlatformAdmin || roles.isPlatformAdmin || features.helpAssistant;

  bool get canDeleteEmployee =>
      isPlatformAdmin || roles.isPlatformAdmin || features.employeeDelete;

  /// Branch managers and location-scoped HR users — not global HR roles.
  bool get isLocationScoped {
    if (roles.isHrManager || roles.isHrSupervisor || roles.isPlatformAdmin) return false;
    final loc = user?.locationId;
    if (loc == null || loc.isEmpty) return false;
    return roles.isBranchManager || roles.isHrUser;
  }

  String? get scopedLocationId => isLocationScoped ? user?.locationId : null;

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    BioTimeUser? user,
    String? employeeName,
    String? employeeCode,
    BioTimeRoles? roles,
    List<BioTimeMenuItem>? menus,
    AuthFeatures? features,
    String? errorMessage,
    String? profileWarning,
    bool? isPlatformAdmin,
    String? activeCompanyId,
    String? activeCompanyName,
    String? activeCompanyCode,
    bool clearError = false,
    bool clearProfileWarning = false,
    bool clearToken = false,
    bool clearActiveCompany = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: clearToken ? null : (token ?? this.token),
      user: user ?? this.user,
      employeeName: employeeName ?? this.employeeName,
      employeeCode: employeeCode ?? this.employeeCode,
      roles: roles ?? this.roles,
      menus: menus ?? this.menus,
      features: features ?? this.features,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      profileWarning: clearProfileWarning ? null : (profileWarning ?? this.profileWarning),
      isPlatformAdmin: isPlatformAdmin ?? this.isPlatformAdmin,
      activeCompanyId: clearActiveCompany ? null : (activeCompanyId ?? this.activeCompanyId),
      activeCompanyName: clearActiveCompany ? null : (activeCompanyName ?? this.activeCompanyName),
      activeCompanyCode: clearActiveCompany ? null : (activeCompanyCode ?? this.activeCompanyCode),
    );
  }

  @override
  List<Object?> get props => [
        status,
        token,
        user,
        employeeName,
        roles,
        menus,
        features,
        errorMessage,
        profileWarning,
        isPlatformAdmin,
        activeCompanyId,
        activeCompanyName,
        activeCompanyCode,
      ];
}

class AuthFeatures extends Equatable {
  const AuthFeatures({
    this.auditLog = false,
    this.helpAssistant = false,
    this.employeeDelete = false,
    this.mobileLocationPunch = false,
  });

  final bool auditLog;
  final bool helpAssistant;
  final bool employeeDelete;
  final bool mobileLocationPunch;

  factory AuthFeatures.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AuthFeatures();
    return AuthFeatures(
      auditLog: json['auditLog'] == true,
      helpAssistant: json['helpAssistant'] == true,
      employeeDelete: json['employeeDelete'] == true,
      mobileLocationPunch: json['mobileLocationPunch'] == true,
    );
  }

  @override
  List<Object?> get props => [auditLog, helpAssistant, employeeDelete, mobileLocationPunch];
}
