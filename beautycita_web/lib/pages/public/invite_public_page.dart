import 'package:flutter/material.dart';

import '../client/invite_page.dart';

/// Public unauthenticated wrapper for the invite flow at `/invitar`.
///
/// Brand gradient AppBar, no sidebar, no client shell.
class InvitePublicPage extends StatelessWidget {
  const InvitePublicPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFec4899), Color(0xFF9333ea)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        title: const Text(
          'BeautyCita \u2014 Invita tu salon',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      // Auth gate on send — show login dialog when unauthenticated user taps Enviar
      body: const InvitePage(),
    );
  }
}
