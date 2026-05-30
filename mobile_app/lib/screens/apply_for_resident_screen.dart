import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

/// Lets an active PUBLIC user apply to become a resident by submitting a
/// unit claim (UserRepository.applyForResident).
///
/// On success we simply pop: AuthGate's profile stream emits the new
/// pending_approval state and renders AwaitingApprovalScreen beneath us.
/// Routing stays in one place (AuthGate) rather than this screen pushing
/// a second copy of the awaiting screen.
class ApplyForResidentScreen extends StatefulWidget {
  final AuthService? authService;
  final UserRepository? userRepository;

  const ApplyForResidentScreen({
    super.key,
    this.authService,
    this.userRepository,
  });

  @override
  State<ApplyForResidentScreen> createState() => _ApplyForResidentScreenState();
}

class _ApplyForResidentScreenState extends State<ApplyForResidentScreen> {
  late final AuthService _authService;
  late final UserRepository _userRepository;

  final _formKey = GlobalKey<FormState>();
  final _unitController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _userRepository = widget.userRepository ?? UserRepository();
  }

  @override
  void dispose() {
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final identity = _authService.currentUser;
    if (identity == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await _userRepository.applyForResident(
        uid: identity.uid,
        requestedUnit: _unitController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_humanize(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _humanize(Object e) {
    if (e is UserRepositoryException) return e.message;
    return 'Could not submit your application. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Resident Access')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter your unit. Your application will be reviewed by an '
                    "administrator; you'll see your status on the home screen.",
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    key: const Key('unitNumberField'),
                    controller: _unitController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: unitNumberInputFormatters,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Unit Number',
                      hintText: unitNumberHint,
                      prefixIcon: Icon(Icons.home_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: validateUnitNumber,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Submit application'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
