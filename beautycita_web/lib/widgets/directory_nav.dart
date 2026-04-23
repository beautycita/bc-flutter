import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _bgColor = Color(0xFFFFFAF5);
const _textSecondary = Color(0xFF666666);
const _brandGradient = LinearGradient(
  colors: [Color(0xFFEC4899), Color(0xFF9333EA), Color(0xFF3B82F6)],
);
const _cardBorder = Color(0xFFF0EBE6);

/// Shared navigation bar for directory pages.
class DirectoryNav extends StatelessWidget {
  const DirectoryNav({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 800;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: _bgColor.withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: _cardBorder)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Logo → home
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.go('/'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/web/img/bc_logo.png',
                            width: 32, height: 32, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(8)),
                              child: const Center(child: Text('BC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ShaderMask(
                          shaderCallback: (bounds) => _brandGradient.createShader(bounds),
                          child: const Text('BeautyCita', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (!isMobile) ...[
                  _navLink(context, 'Inicio', '/'),
                  const SizedBox(width: 24),
                  _navLink(context, 'Directorio', '/salones'),
                  const SizedBox(width: 24),
                  _navLink(context, 'Soporte', '/soporte'),
                  const SizedBox(width: 24),
                ],
                // Login
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.go('/auth'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login_rounded, size: 16, color: _textSecondary),
                        const SizedBox(width: 6),
                        Text('Iniciar sesion', style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 16),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => context.go('/reservar'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(10)),
                        child: const Text('Reservar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navLink(BuildContext context, String label, String route) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(route),
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textSecondary)),
      ),
    );
  }
}
