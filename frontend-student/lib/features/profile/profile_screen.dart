import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/errors/app_exception.dart';
import '../../core/widgets/status_views.dart';
import '../auth/models.dart';
import '../student_repository.dart';
import 'models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.session,
  });

  final StudentRepository repository;
  final StudentSession session;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<TransportProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    _profileFuture = widget.repository.getTransportProfile(
      widget.session.regNo,
    );
  }

  void _retry() {
    setState(_loadProfile);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TransportProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading your profile...');
        }

        if (snapshot.hasError) {
          final message = snapshot.error is AppException
              ? (snapshot.error as AppException).message
              : 'Unable to load your transport profile. Please try again.';

          return EmptyState(
            icon: Icons.person_off_outlined,
            title: 'Profile unavailable',
            message: message,
            action: OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return EmptyState(
            icon: Icons.person_off_outlined,
            title: 'Profile unavailable',
            message: 'No transport profile was returned.',
            action: OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          );
        }

        final profile = snapshot.data!;

        final name = profile.studentName.trim().isEmpty
            ? widget.session.name
            : profile.studentName;

        final regNo = profile.regNo.trim().isEmpty
            ? widget.session.regNo
            : profile.regNo;

        final routeNumber = profile.morningRouteNumber.trim();
        final routeName = profile.morningRouteName.trim();
        final acType = profile.acType.trim();

        final isAc = acType.toUpperCase() == 'AC';

        return RefreshIndicator(
          onRefresh: () async {
            _retry();
            try {
              await _profileFuture;
            } catch (_) {
              // The FutureBuilder displays the error state.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              32,
            ),
            children: [
              _ProfileHeader(
                name: name,
                regNo: regNo,
                active: widget.session.active,
              ),

              const SizedBox(height: AppSpacing.lg),

              const _SectionHeading(
                title: 'Personal information',
                subtitle: 'Your registered student details',
              ),

              const SizedBox(height: AppSpacing.md),

              _InformationCard(
                children: [
                  _ProfileField(
                    icon: Icons.badge_outlined,
                    label: 'Full name',
                    value: name,
                  ),
                  const _FieldDivider(),
                  _ProfileField(
                    icon: Icons.fingerprint_rounded,
                    label: 'Registration number',
                    value: regNo,
                  ),
                  const _FieldDivider(),
                  _ProfileField(
                    icon: Icons.verified_user_outlined,
                    label: 'Account status',
                    value: widget.session.active ? 'Active' : 'Inactive',
                    valueColor: widget.session.active
                        ? AppColors.success
                        : AppColors.danger,
                    valueIcon: widget.session.active
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              const _SectionHeading(
                title: 'Transport details',
                subtitle: 'Your current morning transport assignment',
              ),

              const SizedBox(height: AppSpacing.md),

              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE4E9F1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.sky,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.directions_bus_rounded,
                            color: AppColors.navy,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Morning route',
                                style: TextStyle(
                                  color: Color(0xFF697386),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your assigned transport',
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _TransportBadge(
                          label: acType.isEmpty
                              ? 'UNKNOWN'
                              : acType.toUpperCase(),
                          isAc: isAc,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ROUTE NUMBER',
                            style: TextStyle(
                              color: Color(0xFF697386),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            routeNumber.isEmpty ? 'Unavailable' : routeNumber,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'ROUTE NAME',
                            style: TextStyle(
                              color: Color(0xFF697386),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            routeName.isEmpty ? 'Unavailable' : routeName,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.navy,
                      size: 21,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'These details reflect your registered student '
                        'and transport information. Contact the transport '
                        'administrator if any information needs correction.',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.regNo,
    required this.active,
  });

  final String name;
  final String regNo;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? 'S'
        : name.trim().characters.first.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.blue],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STUDENT PROFILE',
                      style: TextStyle(
                        color: Color(0xFFCADCF8),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name.isEmpty ? 'Student' : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      regNo,
                      style: const TextStyle(
                        color: Color(0xFFD5E3F8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: active
                      ? const Color(0xFF8EF0BC)
                      : const Color(0xFFFFD18B),
                  size: 16,
                ),
                const SizedBox(width: 7),
                Text(
                  active ? 'Active student account' : 'Inactive account',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF697386),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueIcon,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? valueIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF697386)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF697386),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value.trim().isEmpty ? 'Unavailable' : value,
                  style: TextStyle(
                    color: valueColor ?? AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (valueIcon != null) ...[
            const SizedBox(width: 8),
            Icon(valueIcon, color: valueColor, size: 18),
          ],
        ],
      ),
    );
  }
}

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 34, color: Color(0xFFE8ECF2));
  }
}

class _TransportBadge extends StatelessWidget {
  const _TransportBadge({required this.label, required this.isAc});

  final String label;
  final bool isAc;

  @override
  Widget build(BuildContext context) {
    final Color foreground = isAc
        ? const Color(0xFF176B49)
        : const Color(0xFF805B12);

    final Color background = isAc
        ? const Color(0xFFE7F6EE)
        : const Color(0xFFFFF4D9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
