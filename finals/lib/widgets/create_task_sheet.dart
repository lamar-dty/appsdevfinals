import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/colors.dart';
import '../../models/task.dart';
import '../../store/task_store.dart';

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────
void showCreateTaskSheet(BuildContext context, {VoidCallback? onSaved}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (_) => _CreateTaskSheet(onSaved: onSaved),
  );
}

// ─────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────
class _CreateTaskSheet extends StatefulWidget {
  final VoidCallback? onSaved;
  const _CreateTaskSheet({this.onSaved});
  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet>
    with SingleTickerProviderStateMixin {

  final _nameCtrl  = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _nameFocus = FocusNode();

  TaskCategory _category  = TaskCategory.assignment;
  TaskPriority _priority  = TaskPriority.medium;
  TaskRepeat   _repeat    = TaskRepeat.once;
  TaskStatus   _status    = TaskStatus.notStarted;
  DateTime     _startDate = DateTime.now();
  DateTime?    _endDate;
  TimeOfDay?   _startTime;
  TimeOfDay?   _endTime;
  bool         _showOptional = false;
  bool         _saving = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_nameFocus);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _nameFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      HapticFeedback.lightImpact();
      FocusScope.of(context).requestFocus(_nameFocus);
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final task = Task(
      id:        DateTime.now().millisecondsSinceEpoch.toString(),
      name:      _nameCtrl.text.trim(),
      category:  _category,
      dueDate:   _startDate,
      endDate:   _endDate,
      dueTime:   _startTime,
      endTime:   _endTime,
      priority:  _priority,
      notes:     _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      repeat:    _repeat,
      status:    _status,
    );

    TaskStore.instance.addTask(task);
    Navigator.pop(context);
    widget.onSaved?.call();
  }

  // ── Date/time pickers ──────────────────────────────────────

  Future<void> _pickStartDate() async {
    final picked = await _showIosDatePicker(
      context,
      initial: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await _showIosDatePicker(
      context,
      initial: _endDate ?? _startDate,
      firstDate: _startDate,
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<DateTime?> _showIosDatePicker(BuildContext ctx, {required DateTime initial, DateTime? firstDate}) {
    return showModalBottomSheet<DateTime>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _IosDatePickerSheet(
        initial: initial,
        firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await _showIosTimePicker(context, initial: _startTime ?? TimeOfDay.now());
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await _showIosTimePicker(context,
        initial: _endTime ?? (_startTime != null
            ? TimeOfDay(hour: (_startTime!.hour + 1) % 24, minute: _startTime!.minute)
            : TimeOfDay.now()));
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<TimeOfDay?> _showIosTimePicker(BuildContext ctx, {required TimeOfDay initial}) {
    return showModalBottomSheet<TimeOfDay>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _IosTimePickerSheet(initial: initial),
    );
  }

  Widget _pickerTheme(BuildContext ctx, Widget child) => Theme(
    data: ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: kTeal, onPrimary: kNavyDark,
        surface: Color(0xFF1B2D5B), onSurface: kWhite,
      ),
      dialogBackgroundColor: const Color(0xFF1B2D5B),
    ),
    child: child,
  );

  // ── Formatting helpers ─────────────────────────────────────

  String _fmtDate(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd    = DateTime(d.year, d.month, d.day);
    if (dd == today) return 'Today';
    if (dd == today.add(const Duration(days: 1))) return 'Tomorrow';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottom = mq.viewInsets.bottom;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: EdgeInsets.only(bottom: bottom),
        decoration: const BoxDecoration(
          color: Color(0xFF1A2D5A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B88E8).withOpacity(0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF9B88E8).withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.task_alt_rounded, color: Color(0xFF9B88E8), size: 21),
                  ),
                  const SizedBox(width: 13),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Create Task',
                          style: TextStyle(color: kWhite, fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Fill in the details below',
                          style: TextStyle(color: kWhite.withOpacity(0.4), fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: kWhite.withOpacity(0.07), shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded, color: kWhite.withOpacity(0.5), size: 17),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: kWhite.withOpacity(0.07)),

            // Body
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mq.size.height * 0.75),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Task name ─────────────────────────────────
                    _FieldLabel(label: 'Task Name', icon: Icons.edit_rounded),
                    const SizedBox(height: 8),
                    _NameField(controller: _nameCtrl, focusNode: _nameFocus),

                    const SizedBox(height: 18),

                    // ── Category ──────────────────────────────────
                    _FieldLabel(label: 'Category', icon: Icons.label_rounded),
                    const SizedBox(height: 8),
                    _CategoryDropdown(value: _category, onChanged: (v) => setState(() => _category = v)),

                    const SizedBox(height: 18),

                    // ── Date & Time ───────────────────────────────
                    _FieldLabel(label: 'Date & Time', icon: Icons.schedule_rounded),
                    const SizedBox(height: 10),
                    _DateTimeSection(
                      startDate:     _startDate,
                      endDate:       _endDate,
                      startTime:     _startTime,
                      endTime:       _endTime,
                      fmtDate:       _fmtDate,
                      fmtTime:       _fmtTime,
                      onPickStartDate: _pickStartDate,
                      onPickEndDate:   _pickEndDate,
                      onPickStartTime: _pickStartTime,
                      onPickEndTime:   _pickEndTime,
                      onClearEndDate:  () => setState(() => _endDate = null),
                      onClearTime:     () => setState(() { _startTime = null; _endTime = null; }),
                    ),

                    const SizedBox(height: 18),

                    // ── Priority ──────────────────────────────────
                    _FieldLabel(label: 'Priority', icon: Icons.flag_rounded),
                    const SizedBox(height: 8),
                    _PriorityChips(value: _priority, onChanged: (v) => setState(() => _priority = v)),

                    const SizedBox(height: 20),

                    // ── Optional toggle ───────────────────────────
                    GestureDetector(
                      onTap: () => setState(() => _showOptional = !_showOptional),
                      child: Row(children: [
                        Expanded(child: Divider(color: kWhite.withOpacity(0.08))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(children: [
                            Text(
                              _showOptional ? 'Less options' : 'More options',
                              style: TextStyle(color: kTeal.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _showOptional ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(Icons.keyboard_arrow_down_rounded, color: kTeal.withOpacity(0.8), size: 17),
                            ),
                          ]),
                        ),
                        Expanded(child: Divider(color: kWhite.withOpacity(0.08))),
                      ]),
                    ),

                    // ── Optional fields ───────────────────────────
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _OptionalSection(
                        notesCtrl: _notesCtrl,
                        repeat: _repeat,
                        status: _status,
                        onRepeatChanged: (v) => setState(() => _repeat = v),
                        onStatusChanged: (v) => setState(() => _status = v),
                      ),
                      crossFadeState: _showOptional
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 260),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Save button ────────────────────────────────────
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: kWhite.withOpacity(0.07)))),
              padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + mq.padding.bottom),
              child: SizedBox(
                width: double.infinity, height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(colors: [Color(0xFF9B88E8), Color(0xFF7B6BC8)]),
                    boxShadow: [BoxShadow(color: const Color(0xFF9B88E8).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _saving ? null : _save,
                      child: Center(
                        child: _saving
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(kWhite)))
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_rounded, color: kWhite, size: 18),
                                  SizedBox(width: 7),
                                  Text('Save Task', style: TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Date & Time Section — redesigned with start/end
// ─────────────────────────────────────────────────────────────
class _DateTimeSection extends StatelessWidget {
  final DateTime startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String Function(DateTime) fmtDate;
  final String Function(TimeOfDay) fmtTime;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndTime;
  final VoidCallback onClearEndDate;
  final VoidCallback onClearTime;

  const _DateTimeSection({
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.fmtDate,
    required this.fmtTime,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onClearEndDate,
    required this.onClearTime,
  });

  bool get _hasTime => startTime != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWhite.withOpacity(0.09)),
      ),
      child: Column(
        children: [
          // ── DATE ROW ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: kTeal, size: 14),
                const SizedBox(width: 7),
                Text('Date', style: TextStyle(color: kWhite.withOpacity(0.45), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                const Spacer(),
                if (endDate != null)
                  GestureDetector(
                    onTap: onClearEndDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kWhite.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.close_rounded, size: 11, color: kWhite.withOpacity(0.35)),
                        const SizedBox(width: 3),
                        Text('Single day', style: TextStyle(color: kWhite.withOpacity(0.35), fontSize: 10, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
            child: Row(
              children: [
                // Start date
                Expanded(
                  child: _DateChip(
                    label: 'Start',
                    value: fmtDate(startDate),
                    onTap: onPickStartDate,
                    accent: kTeal,
                  ),
                ),
                // Arrow or add-end-date
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: endDate != null
                      ? Icon(Icons.arrow_forward_rounded, color: kWhite.withOpacity(0.25), size: 16)
                      : GestureDetector(
                          onTap: onPickEndDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: kTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kTeal.withOpacity(0.25)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.add_rounded, size: 12, color: kTeal.withOpacity(0.7)),
                              const SizedBox(width: 3),
                              Text('End', style: TextStyle(color: kTeal.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                ),
                // End date (if set)
                Expanded(
                  child: endDate != null
                      ? _DateChip(
                          label: 'End',
                          value: fmtDate(endDate!),
                          onTap: onPickEndDate,
                          accent: const Color(0xFF9B88E8),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // ── DIVIDER ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Divider(height: 1, color: kWhite.withOpacity(0.07)),
          ),

          // ── TIME ROW ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, color: const Color(0xFF9B88E8), size: 14),
                const SizedBox(width: 7),
                Text('Time', style: TextStyle(color: kWhite.withOpacity(0.45), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                const Spacer(),
                if (_hasTime)
                  GestureDetector(
                    onTap: onClearTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kWhite.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.close_rounded, size: 11, color: kWhite.withOpacity(0.35)),
                        const SizedBox(width: 3),
                        Text('Clear', style: TextStyle(color: kWhite.withOpacity(0.35), fontSize: 10, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Row(
              children: [
                // Start time
                Expanded(
                  child: _hasTime
                      ? _DateChip(
                          label: 'Start',
                          value: fmtTime(startTime!),
                          onTap: onPickStartTime,
                          accent: const Color(0xFF9B88E8),
                          icon: Icons.access_time_rounded,
                        )
                      : _AddTimeChip(label: 'Add start time', onTap: onPickStartTime),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _hasTime
                      ? Icon(Icons.arrow_forward_rounded, color: kWhite.withOpacity(0.25), size: 16)
                      : const SizedBox(width: 16),
                ),
                // End time
                Expanded(
                  child: _hasTime
                      ? (endTime != null
                          ? _DateChip(
                              label: 'End',
                              value: fmtTime(endTime!),
                              onTap: onPickEndTime,
                              accent: kTeal,
                              icon: Icons.access_time_rounded,
                            )
                          : _AddTimeChip(label: 'Add end time', onTap: onPickEndTime))
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color accent;
  final IconData? icon;

  const _DateChip({
    required this.label,
    required this.value,
    required this.onTap,
    required this.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: accent.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 11, color: accent.withOpacity(0.7)),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
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

class _AddTimeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddTimeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: kWhite.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kWhite.withOpacity(0.08), style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 14, color: kWhite.withOpacity(0.25)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: kWhite.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Field label
// ─────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FieldLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: kSubtitle, size: 12),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: kSubtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Task name field
// ─────────────────────────────────────────────────────────────
class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const _NameField({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWhite.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: const TextStyle(color: kWhite, fontSize: 17, fontWeight: FontWeight.w600),
        maxLines: 2, minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'What needs to be done?',
          hintStyle: TextStyle(color: kWhite.withOpacity(0.22), fontSize: 17, fontWeight: FontWeight.w600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Category dropdown
// ─────────────────────────────────────────────────────────────
class _CategoryDropdown extends StatelessWidget {
  final TaskCategory value;
  final ValueChanged<TaskCategory> onChanged;
  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: value.color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: value.color.withOpacity(0.35)),
        ),
        child: Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: value.color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.isAcademic ? 'Academic Task' : 'Personal',
                style: TextStyle(color: value.color.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              Text(value.label, style: TextStyle(color: value.color, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          )),
          Icon(Icons.expand_more_rounded, color: value.color.withOpacity(0.6), size: 18),
        ]),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(selected: value, onSelected: (v) { onChanged(v); Navigator.pop(context); }),
    );
  }
}

class _CategorySheet extends StatelessWidget {
  final TaskCategory selected;
  final ValueChanged<TaskCategory> onSelected;
  const _CategorySheet({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2D5B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kWhite.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 14, bottom: 18),
                decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2))),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(children: [
                Container(width: 42, height: 42,
                  decoration: BoxDecoration(color: kTeal.withOpacity(0.14), shape: BoxShape.circle, border: Border.all(color: kTeal.withOpacity(0.3), width: 1.5)),
                  child: const Icon(Icons.label_rounded, color: kTeal, size: 21)),
                const SizedBox(width: 13),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Select Category', style: TextStyle(color: kWhite, fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('Choose what kind of task this is', style: TextStyle(color: kWhite.withOpacity(0.4), fontSize: 12)),
                ]),
              ]),
            ),

            const SizedBox(height: 16),
            Divider(color: kWhite.withOpacity(0.07), thickness: 1, indent: 22, endIndent: 22),
            const SizedBox(height: 6),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: _GroupHeader(label: 'ACADEMIC TASK'),
            ),
            ...[TaskCategory.assignment, TaskCategory.project, TaskCategory.assessment].map((c) =>
              _CatCard(cat: c, selected: selected, onTap: () => onSelected(c))),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: _GroupHeader(label: 'PERSONAL'),
            ),
            _CatCard(cat: TaskCategory.personalTask, selected: selected, onTap: () => onSelected(TaskCategory.personalTask)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(label, style: TextStyle(color: kWhite.withOpacity(0.28), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
  );
}

class _CatCard extends StatefulWidget {
  final TaskCategory cat, selected;
  final VoidCallback onTap;
  const _CatCard({required this.cat, required this.selected, required this.onTap});
  @override State<_CatCard> createState() => _CatCardState();
}

class _CatCardState extends State<_CatCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.cat.color;
    final sel = widget.cat == widget.selected;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: (_pressed || sel) ? c.withOpacity(0.12) : kWhite.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (_pressed || sel) ? c.withOpacity(0.55) : kWhite.withOpacity(0.08), width: 1.3),
        ),
        child: Row(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(color: c.withOpacity(0.13), borderRadius: BorderRadius.circular(13), border: Border.all(color: c.withOpacity(0.25), width: 1.2)),
            child: Icon(Icons.label_rounded, color: c, size: 22)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.cat.label, style: const TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(_catDesc(widget.cat), style: TextStyle(color: kWhite.withOpacity(0.37), fontSize: 12)),
          ])),
          const SizedBox(width: 6),
          if (sel)
            Container(width: 22, height: 22, decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: kWhite, size: 14))
          else
            Icon(Icons.chevron_right_rounded, color: kWhite.withOpacity(0.2), size: 20),
        ]),
      ),
    );
  }

  String _catDesc(TaskCategory c) {
    switch (c) {
      case TaskCategory.assignment: return 'Homework, readings, problem sets';
      case TaskCategory.project:    return 'Long-term or group project work';
      case TaskCategory.assessment: return 'Quiz, exam, or graded test';
      case TaskCategory.personalTask: return 'Errands, goals, personal to-dos';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Priority chips
// ─────────────────────────────────────────────────────────────
class _PriorityChips extends StatelessWidget {
  final TaskPriority value;
  final ValueChanged<TaskPriority> onChanged;
  const _PriorityChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: TaskPriority.values.map((p) {
        final sel = p == value;
        final isLast = p == TaskPriority.high;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(right: isLast ? 0 : 8),
              height: 46,
              decoration: BoxDecoration(
                color: sel ? p.color.withOpacity(0.16) : kWhite.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? p.color.withOpacity(0.55) : kWhite.withOpacity(0.08), width: sel ? 1.5 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_priorityIcon(p), color: sel ? p.color : kWhite.withOpacity(0.3), size: 15),
                  const SizedBox(height: 3),
                  Text(p.label, style: TextStyle(color: sel ? p.color : kWhite.withOpacity(0.35), fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _priorityIcon(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:    return Icons.arrow_downward_rounded;
      case TaskPriority.medium: return Icons.remove_rounded;
      case TaskPriority.high:   return Icons.arrow_upward_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Optional section
// ─────────────────────────────────────────────────────────────
class _OptionalSection extends StatelessWidget {
  final TextEditingController notesCtrl;
  final TaskRepeat repeat;
  final TaskStatus status;
  final ValueChanged<TaskRepeat> onRepeatChanged;
  final ValueChanged<TaskStatus> onStatusChanged;

  const _OptionalSection({
    required this.notesCtrl, required this.repeat, required this.status,
    required this.onRepeatChanged, required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),

        _FieldLabel(label: 'Initial Status', icon: Icons.swap_horiz_rounded),
        const SizedBox(height: 8),
        _StatusChips(value: status, onChanged: onStatusChanged),

        const SizedBox(height: 18),

        _FieldLabel(label: 'Repeat', icon: Icons.repeat_rounded),
        const SizedBox(height: 8),
        Row(
          children: TaskRepeat.values.map((r) {
            final sel = r == repeat;
            final isLast = r == TaskRepeat.weekly;
            return Expanded(
              child: GestureDetector(
                onTap: () => onRepeatChanged(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(right: isLast ? 0 : 8),
                  height: 42,
                  decoration: BoxDecoration(
                    color: sel ? kTeal.withOpacity(0.13) : kWhite.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: sel ? kTeal.withOpacity(0.5) : kWhite.withOpacity(0.08), width: sel ? 1.5 : 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_repeatIcon(r), color: sel ? kTeal : kWhite.withOpacity(0.3), size: 13),
                      const SizedBox(width: 5),
                      Text(r.label, style: TextStyle(color: sel ? kTeal : kWhite.withOpacity(0.35), fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 18),

        _FieldLabel(label: 'Notes', icon: Icons.notes_rounded),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kWhite.withOpacity(0.05),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: kWhite.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: notesCtrl,
            style: const TextStyle(color: kWhite, fontSize: 13),
            maxLines: 3, minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Add a reminder or extra context…',
              hintStyle: TextStyle(color: kWhite.withOpacity(0.22), fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  IconData _repeatIcon(TaskRepeat r) {
    switch (r) {
      case TaskRepeat.once:   return Icons.looks_one_rounded;
      case TaskRepeat.daily:  return Icons.wb_sunny_rounded;
      case TaskRepeat.weekly: return Icons.calendar_view_week_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Status chips
// ─────────────────────────────────────────────────────────────
class _StatusChips extends StatelessWidget {
  final TaskStatus value;
  final ValueChanged<TaskStatus> onChanged;
  const _StatusChips({required this.value, required this.onChanged});

  static const _labels = {
    TaskStatus.notStarted: 'Not Started',
    TaskStatus.inProgress: 'In Progress',
    TaskStatus.completed:  'Completed',
  };
  static const _colors = {
    TaskStatus.notStarted: Color(0xFF8FA6C8),
    TaskStatus.inProgress: Color(0xFF4A90D9),
    TaskStatus.completed:  Color(0xFF3BBFA3),
  };
  static const _icons = {
    TaskStatus.notStarted: Icons.radio_button_unchecked_rounded,
    TaskStatus.inProgress: Icons.timelapse_rounded,
    TaskStatus.completed:  Icons.check_circle_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: TaskStatus.values.map((s) {
        final sel = s == value;
        final c = _colors[s]!;
        final isLast = s == TaskStatus.completed;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(right: isLast ? 0 : 8),
              height: 48,
              decoration: BoxDecoration(
                color: sel ? c.withOpacity(0.14) : kWhite.withOpacity(0.04),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: sel ? c.withOpacity(0.55) : kWhite.withOpacity(0.08), width: sel ? 1.5 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_icons[s]!, color: sel ? c : kWhite.withOpacity(0.3), size: 14),
                  const SizedBox(height: 3),
                  Text(
                    s == TaskStatus.notStarted ? 'Pending' : _labels[s]!.split(' ').first,
                    style: TextStyle(color: sel ? c : kWhite.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// iOS-style drum-roll time picker sheet
// ─────────────────────────────────────────────────────────────
class _IosTimePickerSheet extends StatefulWidget {
  final TimeOfDay initial;
  const _IosTimePickerSheet({required this.initial});
  @override
  State<_IosTimePickerSheet> createState() => _IosTimePickerSheetState();
}

class _IosTimePickerSheetState extends State<_IosTimePickerSheet> {
  static const double _itemH   = 52.0;
  static const double _visible = 5;   // how many rows show at once
  static const double _listH   = _itemH * _visible;

  late int _hour12;   // 1–12
  late int _minute;   // 0–59
  late int _amPm;     // 0=AM, 1=PM

  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late FixedExtentScrollController _amPmCtrl;

  @override
  void initState() {
    super.initState();
    final h = widget.initial.hour;
    _amPm   = h >= 12 ? 1 : 0;
    _hour12 = h % 12 == 0 ? 12 : h % 12;
    _minute = widget.initial.minute;

    // Use a large loop offset so users can spin freely
    _hourCtrl   = FixedExtentScrollController(initialItem: 1200 + (_hour12 - 1));
    _minuteCtrl = FixedExtentScrollController(initialItem: 3000 + _minute);
    _amPmCtrl   = FixedExtentScrollController(initialItem: _amPm);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _amPmCtrl.dispose();
    super.dispose();
  }

  TimeOfDay get _result {
    int hour = _hour12 % 12 + (_amPm == 1 ? 12 : 0);
    return TimeOfDay(hour: hour, minute: _minute);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, 24 + mq.padding.bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2D5A),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: kWhite.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B88E8).withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF9B88E8).withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.access_time_rounded, color: Color(0xFF9B88E8), size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Set Time', style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Scroll to choose', style: TextStyle(color: kWhite.withOpacity(0.38), fontSize: 12)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: kWhite.withOpacity(0.07), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: kWhite.withOpacity(0.45), size: 16),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Divider(height: 1, color: kWhite.withOpacity(0.07)),
          const SizedBox(height: 8),

          // ── Drum rolls ────────────────────────────────────
          SizedBox(
            height: _listH,
            child: Stack(
              children: [
                // Selection highlight band
                Positioned(
                  top: _itemH * ((_visible - 1) / 2),
                  left: 16, right: 16,
                  height: _itemH,
                  child: Container(
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kWhite.withOpacity(0.1)),
                    ),
                  ),
                ),

                // Top fade
                Positioned(
                  top: 0, left: 0, right: 0,
                  height: _itemH * 1.5,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [const Color(0xFF1A2D5A), const Color(0xFF1A2D5A).withOpacity(0)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom fade
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: _itemH * 1.5,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [const Color(0xFF1A2D5A), const Color(0xFF1A2D5A).withOpacity(0)],
                        ),
                      ),
                    ),
                  ),
                ),

                // Wheels row
                Row(
                  children: [
                    // Hour wheel
                    Expanded(
                      flex: 3,
                      child: _Wheel(
                        controller: _hourCtrl,
                        itemCount: 12,
                        labelBuilder: (i) => '${(i % 12) + 1}',
                        onChanged: (i) => setState(() => _hour12 = (i % 12) + 1),
                      ),
                    ),
                    // Colon
                    Text(':', style: TextStyle(color: kWhite.withOpacity(0.6), fontSize: 28, fontWeight: FontWeight.w300)),
                    // Minute wheel
                    Expanded(
                      flex: 3,
                      child: _Wheel(
                        controller: _minuteCtrl,
                        itemCount: 60,
                        labelBuilder: (i) => (i % 60).toString().padLeft(2, '0'),
                        onChanged: (i) => setState(() => _minute = i % 60),
                      ),
                    ),
                    // AM/PM wheel
                    Expanded(
                      flex: 2,
                      child: _Wheel(
                        controller: _amPmCtrl,
                        itemCount: 2,
                        looping: false,
                        labelBuilder: (i) => i == 0 ? 'AM' : 'PM',
                        onChanged: (i) => setState(() => _amPm = i),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: kWhite.withOpacity(0.07)),

          // ── Confirm button ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [Color(0xFF9B88E8), Color(0xFF7B6BC8)]),
                  boxShadow: [BoxShadow(color: const Color(0xFF9B88E8).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context, _result),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded, color: kWhite, size: 18),
                          const SizedBox(width: 7),
                          Text(
                            _formatPreview(_result),
                            style: const TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPreview(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

// ─────────────────────────────────────────────────────────────
// Single drum-roll wheel
// ─────────────────────────────────────────────────────────────
class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int) labelBuilder;
  final ValueChanged<int> onChanged;
  final bool looping;

  const _Wheel({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.onChanged,
    this.looping = true,
  });

  @override
  Widget build(BuildContext context) {
    const double itemH = _IosTimePickerSheetState._itemH;

    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemH,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.4,
      perspective: 0.003,
      squeeze: 1.0,
      onSelectedItemChanged: onChanged,
      childDelegate: looping
          ? ListWheelChildLoopingListDelegate(
              children: List.generate(itemCount, (i) => _WheelItem(label: labelBuilder(i))),
            )
          : ListWheelChildListDelegate(
              children: List.generate(itemCount, (i) => _WheelItem(label: labelBuilder(i))),
            ),
    );
  }
}

class _WheelItem extends StatelessWidget {
  final String label;
  final bool dimmed;
  const _WheelItem({required this.label, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: dimmed ? kWhite.withOpacity(0.18) : kWhite,
          fontSize: 26,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// iOS-style drum-roll date picker sheet
// ─────────────────────────────────────────────────────────────
class _IosDatePickerSheet extends StatefulWidget {
  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;
  const _IosDatePickerSheet({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
  });
  @override
  State<_IosDatePickerSheet> createState() => _IosDatePickerSheetState();
}

class _IosDatePickerSheetState extends State<_IosDatePickerSheet> {
  static const double _itemH  = 52.0;
  static const double _visible = 5;
  static const double _listH  = _itemH * _visible;

  static const List<String> _monthNames = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  late int _month; // 1–12
  late int _day;   // 1–31
  late int _year;

  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _yearCtrl;

  // Year range
  late final int _firstYear;
  late final int _lastYear;

  @override
  void initState() {
    super.initState();
    _month = widget.initial.month;
    _day   = widget.initial.day;
    _year  = widget.initial.year;

    _firstYear = widget.firstDate.year;
    _lastYear  = widget.lastDate.year;

    // Large offset for month/day so users can spin freely; year is exact
    _monthCtrl = FixedExtentScrollController(initialItem: 1200 + (_month - 1));
    _dayCtrl   = FixedExtentScrollController(initialItem: 3000 + (_day - 1));
    _yearCtrl  = FixedExtentScrollController(initialItem: _year - _firstYear);
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  DateTime get _result => DateTime(
    _year,
    _month,
    _day.clamp(1, _daysInMonth),
  );

  String _fmtResult(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd    = DateTime(d.year, d.month, d.day);
    if (dd == today) return 'Today';
    if (dd == today.add(const Duration(days: 1))) return 'Tomorrow';
    return '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, 24 + mq.padding.bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2D5A),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: kWhite.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: kTeal.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: kTeal.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: kTeal, size: 17),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Set Date', style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Scroll to choose', style: TextStyle(color: kWhite.withOpacity(0.38), fontSize: 12)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: kWhite.withOpacity(0.07), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: kWhite.withOpacity(0.45), size: 16),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Divider(height: 1, color: kWhite.withOpacity(0.07)),
          const SizedBox(height: 8),

          // ── Drum rolls ────────────────────────────────────
          SizedBox(
            height: _listH,
            child: Stack(
              children: [
                // Selection highlight band
                Positioned(
                  top: _itemH * ((_visible - 1) / 2),
                  left: 16, right: 16,
                  height: _itemH,
                  child: Container(
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kWhite.withOpacity(0.1)),
                    ),
                  ),
                ),
                // Top fade
                Positioned(
                  top: 0, left: 0, right: 0,
                  height: _itemH * 1.5,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [const Color(0xFF1A2D5A), const Color(0xFF1A2D5A).withOpacity(0)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom fade
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: _itemH * 1.5,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [const Color(0xFF1A2D5A), const Color(0xFF1A2D5A).withOpacity(0)],
                        ),
                      ),
                    ),
                  ),
                ),

                // Wheels row
                Row(
                  children: [
                    // Month wheel
                    Expanded(
                      flex: 3,
                      child: _Wheel(
                        controller: _monthCtrl,
                        itemCount: 12,
                        labelBuilder: (i) => _monthNames[i % 12],
                        onChanged: (i) => setState(() => _month = (i % 12) + 1),
                      ),
                    ),
                    // Day wheel
                    Expanded(
                      flex: 2,
                      child: ListWheelScrollView.useDelegate(
                        controller: _dayCtrl,
                        itemExtent: _itemH,
                        physics: const FixedExtentScrollPhysics(),
                        diameterRatio: 1.4,
                        perspective: 0.003,
                        onSelectedItemChanged: (i) => setState(() => _day = (i % 31) + 1),
                        childDelegate: ListWheelChildLoopingListDelegate(
                          children: List.generate(31, (i) => _WheelItem(
                            label: '${i + 1}',
                            // Dim days beyond current month length
                            dimmed: (i + 1) > _daysInMonth,
                          )),
                        ),
                      ),
                    ),
                    // Year wheel (no looping — finite range)
                    Expanded(
                      flex: 3,
                      child: _Wheel(
                        controller: _yearCtrl,
                        itemCount: _lastYear - _firstYear + 1,
                        looping: false,
                        labelBuilder: (i) => '${_firstYear + i}',
                        onChanged: (i) => setState(() => _year = _firstYear + i),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: kWhite.withOpacity(0.07)),

          // ── Confirm button ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [kTeal, Color(0xFF6AB8B3)]),
                  boxShadow: [BoxShadow(color: kTeal.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context, _result),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded, color: kNavyDark, size: 18),
                          const SizedBox(width: 7),
                          Text(
                            _fmtResult(_result),
                            style: const TextStyle(color: kNavyDark, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}