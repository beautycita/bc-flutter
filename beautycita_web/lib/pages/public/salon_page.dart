import 'package:flutter/material.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:go_router/go_router.dart';


/// Public salon landing page — accessible at /salon/:slug
/// Shows salon name, photo, services, and per-service booking buttons.
class SalonPage extends StatefulWidget {
  final String slug;
  const SalonPage({super.key, required this.slug});

  @override
  State<SalonPage> createState() => _SalonPageState();
}

class _SalonPageState extends State<SalonPage> {
  Map<String, dynamic>? _business;
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Try to find by ID first, then by slug
      var biz = await BCSupabase.client
          .from('businesses')
          .select('id, name, photo_url, description, phone, city, is_active')
          .eq('id', widget.slug)
          .maybeSingle();

      biz ??= await BCSupabase.client
          .from('businesses')
          .select('id, name, photo_url, description, phone, city, is_active')
          .eq('slug', widget.slug)
          .maybeSingle();

      if (biz == null || biz['is_active'] != true) {
        setState(() {
          _error = 'Salon no encontrado';
          _loading = false;
        });
        return;
      }

      final services = await BCSupabase.client
          .from('business_services')
          .select('id, name, price, duration_minutes, category')
          .eq('business_id', biz['id'] as String)
          .eq('is_active', true)
          .order('name');

      setState(() {
        _business = biz;
        _services = (services as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar el salon';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      );
    }

    final biz = _business!;
    final name = biz['name'] as String? ?? 'Salon';
    final photoUrl = biz['photo_url'] as String?;
    final description = biz['description'] as String?;
    final city = biz['city'] as String?;
    final bizId = biz['id'] as String;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Salon photo
                if (photoUrl != null && photoUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      photoUrl,
                      height: 240,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(height: 100),
                    ),
                  ),
                const SizedBox(height: 24),

                // Salon name
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (city != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    city,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(fontSize: 15, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 32),

                // Services list
                if (_services.isEmpty)
                  Text(
                    'Este salon aun no ha publicado servicios',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  )
                else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Servicios',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_services.length, (i) {
                    final svc = _services[i];
                    final svcName = svc['name'] as String? ?? 'Servicio';
                    final price = (svc['price'] as num?)?.toDouble();
                    final duration = svc['duration_minutes'] as int?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Text(
                          svcName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            if (price != null)
                              Text(
                                '\$${price.toStringAsFixed(0)} MXN',
                                style: TextStyle(fontSize: 13),
                              ),
                            if (price != null && duration != null)
                              const Text(' · '),
                            if (duration != null)
                              Text(
                                '${duration} min',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        trailing: FilledButton(
                          onPressed: () {
                            context.go('/reservar?salon=$bizId&service=${svc['id']}');
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            'Reservar',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 40),

                // BeautyCita branding
                Text(
                  'Powered by BeautyCita',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
