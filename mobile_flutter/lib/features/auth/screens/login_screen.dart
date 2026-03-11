import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/theme/colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool   _loading      = false;
  bool   _obscure      = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _errorMessage = null; });

    try {
      final dio     = ref.read(apiClientProvider);
      final storage = ref.read(secureStorageProvider);

      final res = await dio.post('/api/v1/auth/login', data: {
        'email':    _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });

      final body = res.data as Map<String, dynamic>;
      final d    = body['data'] as Map<String, dynamic>;
      final user = d['user'] as Map<String, dynamic>;

      await storage.saveAuthData(
        token:          d['token'] as String,
        organizationId: (user['organization_id'] ?? user['current_organization_id'] ?? '')
            .toString(),
        userJson:       jsonEncode(user),
      );

      if (mounted) context.go(AppRoutes.home);
    } on DioException catch (e) {
      final msg = e.response?.data?['errors']?.first?.toString()
          ?? e.message
          ?? 'Login failed. Please try again.';
      setState(() { _errorMessage = msg; });
    } catch (_) {
      setState(() { _errorMessage = 'An unexpected error occurred.'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                // ── Logo ───────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: OlColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        'OL',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'OrdWave',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: OlColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to your account',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: OlColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 40),

                // ── Error banner ───────────────────────────────────────
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OlColors.errorLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: OlColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: OlColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: OlColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Email ──────────────────────────────────────────────
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'you@company.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Email is required'
                      : null,
                ),
                const SizedBox(height: 16),

                // ── Password ───────────────────────────────────────────
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() { _obscure = !_obscure; }),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
                ),
                const SizedBox(height: 28),

                // ── Submit ─────────────────────────────────────────────
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
