import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        title: Text('PARTS MARKETPLACE', style: Theme.of(context).textTheme.displaySmall),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryCyan,
          labelColor: AppTheme.primaryCyan,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
          tabs: const [
            Tab(text: 'COMPATIBLE'),
            Tab(text: 'TECHNICIANS'),
            Tab(text: 'COMPARE'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search parts, accessories...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryCyan),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CompatiblePartsTab(),
                _TechniciansTab(),
                _PriceCompareTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatiblePartsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final parts = [
      _Part(
        name: 'Dell WDX0R Battery 40Wh',
        compatibility: '100% compatible',
        price: 49.99,
        rating: 4.8,
        reviews: 1204,
        availability: 'In Stock',
        condition: 'New',
        imageIcon: Icons.battery_charging_full,
        color: AppTheme.accentGreen,
      ),
      _Part(
        name: '8GB DDR4 2666MHz SODIMM',
        compatibility: '98% compatible',
        price: 32.99,
        rating: 4.6,
        reviews: 892,
        availability: 'In Stock',
        condition: 'New',
        imageIcon: Icons.memory,
        color: AppTheme.primaryCyan,
      ),
      _Part(
        name: '512GB M.2 PCIe NVMe SSD',
        compatibility: '100% compatible',
        price: 79.99,
        rating: 4.9,
        reviews: 2341,
        availability: 'In Stock',
        condition: 'New',
        imageIcon: Icons.storage,
        color: AppTheme.accentPurple,
      ),
      _Part(
        name: 'Dell 15.6" FHD IPS Panel',
        compatibility: '95% compatible',
        price: 124.99,
        rating: 4.4,
        reviews: 456,
        availability: 'Ships in 3-5 days',
        condition: 'New',
        imageIcon: Icons.monitor,
        color: AppTheme.accentOrange,
      ),
      _Part(
        name: 'Dell Keyboard US Layout',
        compatibility: '100% compatible',
        price: 28.99,
        rating: 4.7,
        reviews: 678,
        availability: 'In Stock',
        condition: 'OEM',
        imageIcon: Icons.keyboard,
        color: AppTheme.primaryBlue,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: parts.length,
      itemBuilder: (context, i) => _PartCard(part: parts[i])
          .animate()
          .fadeIn(delay: Duration(milliseconds: i * 80))
          .slideY(begin: 0.2),
    );
  }
}

class _Part {
  final String name;
  final String compatibility;
  final double price;
  final double rating;
  final int reviews;
  final String availability;
  final String condition;
  final IconData imageIcon;
  final Color color;

  _Part({
    required this.name,
    required this.compatibility,
    required this.price,
    required this.rating,
    required this.reviews,
    required this.availability,
    required this.condition,
    required this.imageIcon,
    required this.color,
  });
}

class _PartCard extends StatelessWidget {
  final _Part part;

  const _PartCard({required this.part});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassWhite),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: part.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: part.color.withOpacity(0.3)),
              ),
              child: Icon(part.imageIcon, color: part.color, size: 26),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 11, color: AppTheme.accentGreen),
                      const SizedBox(width: 3),
                      Text(
                        part.compatibility,
                        style: const TextStyle(
                          color: AppTheme.accentGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.star, size: 11, color: AppTheme.warningAmber),
                      const SizedBox(width: 3),
                      Text(
                        '${part.rating} (${part.reviews})',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        part.availability,
                        style: TextStyle(
                          color: part.availability.startsWith('In')
                              ? AppTheme.accentGreen
                              : AppTheme.warningAmber,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${part.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.primaryCyan,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'BUY',
                    style: TextStyle(
                      color: AppTheme.primaryCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TechniciansTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final techs = [
      _Technician(
        name: 'TechPro Repairs',
        specialty: 'Electronics & Laptops',
        rating: 4.9,
        reviews: 234,
        distanceKm: 1.2,
        priceRange: '\$\$',
        available: true,
      ),
      _Technician(
        name: 'QuickFix Center',
        specialty: 'All Brands',
        rating: 4.6,
        reviews: 891,
        distanceKm: 2.8,
        priceRange: '\$',
        available: true,
      ),
      _Technician(
        name: 'Dell Authorized Service',
        specialty: 'Dell Products Only',
        rating: 4.8,
        reviews: 1205,
        distanceKm: 5.1,
        priceRange: '\$\$\$',
        available: false,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: techs.length,
      itemBuilder: (context, i) => _TechnicianCard(tech: techs[i])
          .animate()
          .fadeIn(delay: Duration(milliseconds: i * 100)),
    );
  }
}

class _Technician {
  final String name;
  final String specialty;
  final double rating;
  final int reviews;
  final double distanceKm;
  final String priceRange;
  final bool available;

  _Technician({
    required this.name,
    required this.specialty,
    required this.rating,
    required this.reviews,
    required this.distanceKm,
    required this.priceRange,
    required this.available,
  });
}

class _TechnicianCard extends StatelessWidget {
  final _Technician tech;

  const _TechnicianCard({required this.tech});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryCyan.withOpacity(0.1),
              border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
            ),
            child: const Icon(Icons.build, color: AppTheme.primaryCyan, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tech.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (tech.available)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                  ],
                ),
                Text(
                  tech.specialty,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 12, color: AppTheme.warningAmber),
                    const SizedBox(width: 3),
                    Text(
                      '${tech.rating} (${tech.reviews})',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.location_on, size: 12, color: AppTheme.primaryCyan),
                    const SizedBox(width: 3),
                    Text(
                      '${tech.distanceKm}km',
                      style: const TextStyle(
                        color: AppTheme.primaryCyan,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tech.priceRange,
                      style: const TextStyle(
                        color: AppTheme.accentGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
                ),
                child: const Text(
                  'CONTACT',
                  style: TextStyle(
                    color: AppTheme.primaryCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceCompareTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BATTERY PRICE COMPARISON',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 12),
              _PriceRow('Amazon', '\$49.99', AppTheme.accentOrange, 2),
              _PriceRow('eBay', '\$38.50', AppTheme.primaryCyan, 5),
              _PriceRow('iFixit', '\$54.99', AppTheme.accentGreen, 1),
              _PriceRow('Newegg', '\$44.99', AppTheme.accentPurple, 3),
              _PriceRow('Dell Official', '\$79.99', AppTheme.warningAmber, 1),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tips_and_updates, color: AppTheme.warningAmber, size: 16),
                  const SizedBox(width: 8),
                  Text('PRICE INSIGHTS', style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Best value: eBay at \$38.50 — 3rd party seller with 98.3% positive feedback. Ships in 2-3 days.\n\nFor warranty: Dell Official offers 1-year replacement guarantee.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String store;
  final String price;
  final Color color;
  final int deliveryDays;

  const _PriceRow(this.store, this.price, this.color, this.deliveryDays);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              store,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 1 - (double.parse(price.replaceAll('\$', '')) / 90),
                backgroundColor: AppTheme.glassWhite,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 55,
            child: Text(
              price,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${deliveryDays}d',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
