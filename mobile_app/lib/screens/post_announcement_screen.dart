import 'package:flutter/material.dart';

// announcement.dart re-exports user_role.dart, so this single import gives us
// both AnnouncementPriority and UserRole.
import '../models/announcement.dart';
import '../services/announcement_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// Announcement composer — opened from [PostAnnouncementEntry] on the
/// privileged homes.
///
/// ─── SECURITY: WHO POSTS IS NOT USER INPUT ──────────────────────────────
/// [postedBy] and [postedByRole] are supplied by the caller FROM THE AUTH
/// SESSION (the AuthIdentity AuthGate routed on) — never typed by the user.
/// They are forwarded verbatim to [AnnouncementRepository.postAnnouncement]
/// so the write matches what the Firestore rule pins to `request.auth.uid`
/// and `request.auth.token.role`. The client-side length/required checks below
/// are a friendly pre-check that MIRRORS the rule's bounds; the rule remains
/// the authoritative gate, so a rejected write is surfaced as a snackbar and
/// success is never assumed.
class PostAnnouncementScreen extends StatefulWidget {
  final String postedBy;
  final UserRole postedByRole;

  /// Injectable for tests; defaults to a live [AnnouncementRepository].
  final AnnouncementRepository? repository;

  const PostAnnouncementScreen({
    super.key,
    required this.postedBy,
    required this.postedByRole,
    this.repository,
  });

  @override
  State<PostAnnouncementScreen> createState() => _PostAnnouncementScreenState();
}

class _PostAnnouncementScreenState extends State<PostAnnouncementScreen> {
  // Mirror the firestore.rules bounds (title 1..200, body ..5000).
  static const int _maxTitle = 200;
  static const int _maxBody = 5000;

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  late final AnnouncementRepository _repo;

  AnnouncementPriority _priority = AnnouncementPriority.info;
  bool _pinned = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AnnouncementRepository();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    // Defensive: the session uid should always be present here (this screen is
    // only reachable from a privileged home), but never post without it.
    if (widget.postedBy.isEmpty) {
      _toast('Not signed in — please sign in again.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _repo.postAnnouncement(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        postedBy: widget.postedBy,
        postedByRole: widget.postedByRole,
        priority: _priority,
        pinned: _pinned,
      );
      if (!mounted) return;
      // Close back to the home; its AnnouncementsFeed updates live via the
      // Firestore stream, so there is nothing to pass back.
      Navigator.of(context).pop(true);
    } catch (e) {
      // The rule (or a transient failure) rejected the write. Surface it;
      // do NOT assume success.
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('Could not post announcement: $e', isError: true);
    }
  }

  void _toast(String text, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? cs.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New announcement')),
      body: SafeArea(
        // Block interaction (incl. re-taps) while the write is in flight.
        child: AbsorbPointer(
          absorbing: _submitting,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  maxLength: _maxTitle,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Water shut-off this Saturday',
                  ),
                  validator: (value) {
                    final t = (value ?? '').trim();
                    if (t.isEmpty) return 'Title is required.';
                    if (t.length > _maxTitle) {
                      return 'Keep the title to $_maxTitle characters or fewer.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _bodyCtrl,
                  maxLength: _maxBody,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'What do residents need to know?',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    final t = (value ?? '').trim();
                    if (t.isEmpty) return 'Message is required.';
                    if (t.length > _maxBody) return 'Message is too long.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Priority', style: tt.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<AnnouncementPriority>(
                  segments: const [
                    ButtonSegment(
                      value: AnnouncementPriority.info,
                      label: Text('Info'),
                      icon: Icon(AppIcons.info),
                    ),
                    ButtonSegment(
                      value: AnnouncementPriority.warning,
                      label: Text('Warning'),
                      icon: Icon(AppIcons.warning),
                    ),
                    ButtonSegment(
                      value: AnnouncementPriority.critical,
                      label: Text('Critical'),
                      icon: Icon(AppIcons.error),
                    ),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (selection) =>
                      setState(() => _priority = selection.first),
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pin to top'),
                  subtitle: Text(
                    'Pinned announcements appear above the rest of the feed.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.announcements),
                  label: Text(_submitting ? 'Posting…' : 'Post announcement'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
