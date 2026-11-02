import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/status_views.dart';
import '../auth/models.dart';
import '../student_repository.dart';
import 'models.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({
    super.key,
    required this.repository,
    required this.session,
  });

  final StudentRepository repository;
  final StudentSession session;

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final TextEditingController _searchController = TextEditingController();

  late Future<List<RouteInfo>> _routesFuture;
  String _selectedType = 'All';

  @override
  void initState() {
    super.initState();
    _routesFuture = widget.repository.getRoutes();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _retry() {
    setState(() {
      _routesFuture = widget.repository.getRoutes();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RouteInfo>>(
      future: _routesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading routes...');
        }

        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.route_outlined,
            title: 'Routes unavailable',
            message: snapshot.error.toString(),
            action: OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          );
        }

        final List<RouteInfo> routes = snapshot.data ?? [];
        final String query = _searchController.text.trim().toLowerCase();

        final List<RouteInfo> filteredRoutes = routes.where((route) {
          final bool matchesSearch =
              query.isEmpty ||
              route.routeNumber.toLowerCase().contains(query) ||
              route.routeName.toLowerCase().contains(query) ||
              route.acType.toLowerCase().contains(query) ||
              route.allowedRoutes.any(
                (area) => area.toLowerCase().contains(query),
              );

          final String type = route.acType.toUpperCase();
          final bool matchesType =
              _selectedType == 'All' ||
              (_selectedType == 'AC' && type == 'AC') ||
              (_selectedType == 'Non-AC' && type != 'AC');

          return matchesSearch && matchesType;
        }).toList();

        final int acCount = routes
            .where((route) => route.acType.toUpperCase() == 'AC')
            .length;
        final int nonAcCount = routes.length - acCount;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            32,
          ),
          children: [
            _RoutesIntro(
              totalRoutes: routes.length,
              acCount: acCount,
              nonAcCount: nonAcCount,
            ),
            const SizedBox(height: AppSpacing.lg),

            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by route, name or area',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close),
                      )
                    : null,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All routes',
                    selected: _selectedType == 'All',
                    onTap: () => setState(() => _selectedType = 'All'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'AC',
                    selected: _selectedType == 'AC',
                    onTap: () => setState(() => _selectedType = 'AC'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Non-AC',
                    selected: _selectedType == 'Non-AC',
                    onTap: () => setState(() => _selectedType = 'Non-AC'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Available routes',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Text(
                  '${filteredRoutes.length} found',
                  style: const TextStyle(
                    color: Color(0xFF697386),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            if (filteredRoutes.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No routes found',
                  message: 'Try another search or change the transport filter.',
                ),
              )
            else
              ...filteredRoutes.map(
                (route) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _RouteCard(route: route),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RoutesIntro extends StatelessWidget {
  const _RoutesIntro({
    required this.totalRoutes,
    required this.acCount,
    required this.nonAcCount,
  });

  final int totalRoutes;
  final int acCount;
  final int nonAcCount;

  @override
  Widget build(BuildContext context) {
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
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Find your route.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Explore transport options and check eligible areas.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _RouteStat(value: '$totalRoutes', label: 'Total routes'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RouteStat(value: '$acCount', label: 'AC'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RouteStat(value: '$nonAcCount', label: 'Non-AC'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteStat extends StatelessWidget {
  const _RouteStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.navy,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppColors.navy : const Color(0xFFDCE2EC),
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route});

  final RouteInfo route;

  @override
  Widget build(BuildContext context) {
    final bool isAc = route.acType.toUpperCase() == 'AC';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EBF2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.sky,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    color: AppColors.navy,
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.routeNumber.isEmpty
                            ? route.routeName
                            : 'Route ${route.routeNumber}',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        route.routeName,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _TransportBadge(isAc: isAc),
              ],
            ),

            if (route.allowedRoutes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              const Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: Color(0xFF697386),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Eligible areas',
                    style: TextStyle(
                      color: Color(0xFF697386),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: route.allowedRoutes.map((area) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FA),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      area,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            if (route.defaultAfternoon) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wb_twilight_rounded,
                      size: 15,
                      color: AppColors.navy,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Default afternoon route',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransportBadge extends StatelessWidget {
  const _TransportBadge({required this.isAc});

  final bool isAc;

  @override
  Widget build(BuildContext context) {
    final Color color = isAc
        ? const Color(0xFF176B49)
        : const Color(0xFF805B12);

    final Color background = isAc
        ? const Color(0xFFE7F6EE)
        : const Color(0xFFFFF4D9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isAc ? 'AC' : 'NON-AC',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
