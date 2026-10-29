import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ============ THEME COLORS (change these to restyle the app) ============
const kPrimary = Color(0xFF6C63FF);
const kPink = Color(0xFFFF6584);
const kBg = Color(0xFFF5F4FF);

const kMainGradient = LinearGradient(
  colors: [Color(0xFF6C63FF), Color(0xFF9B5DE5), Color(0xFFFF6584)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

void main() => runApp(const TodoApp());

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kPrimary,
        scaffoldBackgroundColor: kBg,
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================ MODELS ============================
enum TaskCategory {
  work('Work', Icons.work_rounded, Color(0xFF6C63FF)),
  study('Study', Icons.menu_book_rounded, Color(0xFF00B8D9)),
  personal('Personal', Icons.favorite_rounded, Color(0xFFFF6584)),
  health('Health', Icons.fitness_center_rounded, Color(0xFF2ECC71));

  const TaskCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class Todo {
  Todo({required this.title, required this.category, this.done = false});
  final String title;
  final TaskCategory category;
  bool done;
}

// ======================= REUSABLE ANIMATION =======================
// Fades + slides a widget in, with an optional delay (for staggered effects)
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.delay = 0});
  final Widget child;
  final int delay;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(_curve),
        child: widget.child,
      ),
    );
  }
}

// ========================== SPLASH SCREEN ==========================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, __, ___) => const HomePage(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kMainGradient),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.elasticOut,
            builder: (context, v, _) => Transform.scale(
              scale: v,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 70, color: kPrimary),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'TaskFlow',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Plan. Do. Achieve.',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
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

// ============================ HOME PAGE ============================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Todo> _todos = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ImagePicker _picker = ImagePicker();
  int _tab = 0; // 0 = Tasks, 1 = Profile
  Uint8List? _profileImage;
  String _name = 'Your Name';

  int get _completed => _todos.where((t) => t.done).length;

  // ---------- Task actions ----------
  void _addTodo(String title, TaskCategory category) {
    _todos.insert(0, Todo(title: title, category: category));
    _listKey.currentState
        ?.insertItem(0, duration: const Duration(milliseconds: 500));
    setState(() {});
  }

  void _toggle(Todo todo) {
    setState(() => todo.done = !todo.done);
  }

  void _delete(Todo todo, {bool animate = true}) {
    final index = _todos.indexOf(todo);
    if (index < 0) return;
    _todos.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) =>
          animate ? _animatedTile(todo, animation, removing: true) : const SizedBox.shrink(),
      duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
    );
    setState(() {});
  }

  // ---------- Profile actions ----------
  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _profileImage = bytes);
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: kPrimary),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: kPink),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_profileImage != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _profileImage = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => NameDialog(initial: _name),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      setState(() => _name = newName.trim());
    }
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskSheet(onAdd: _addTodo),
    );
  }

  // ---------- Animated list item ----------
  Widget _animatedTile(Todo todo, Animation<double> animation,
      {bool removing = false}) {
    final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position:
              curved.drive(Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)),
          child: TaskTile(
            todo: todo,
            onToggle: removing ? null : () => _toggle(todo),
            onDelete: removing ? null : () => _delete(todo),
            onSwiped: removing ? null : () => _delete(todo, animate: false),
          ),
        ),
      ),
    );
  }

  // ---------- Tasks tab ----------
  Widget _buildHeader(double progress) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final total = _todos.length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 20, 24, 28),
      decoration: const BoxDecoration(
        gradient: kMainGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$greeting 👋',
              style: const TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            _name,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  total == 0
                      ? 'No tasks yet. Tap + to start'
                      : '$_completed of $total tasks completed',
                  style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasks() {
    final total = _todos.length;
    final progress = total == 0 ? 0.0 : _completed / total;

    return Column(
      children: [
        _buildHeader(progress),
        Expanded(
          child: Stack(
            children: [
              AnimatedList(
                key: _listKey,
                padding: const EdgeInsets.only(top: 12, bottom: 100),
                initialItemCount: _todos.length,
                itemBuilder: (context, index, animation) =>
                    _animatedTile(_todos[index], animation),
              ),
              if (_todos.isEmpty) const IgnorePointer(child: EmptyState()),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        sizing: StackFit.expand,
        index: _tab,
        children: [
          _buildTasks(),
          _tab == 1
              ? ProfilePage(
                  todos: _todos,
                  name: _name,
                  profileImage: _profileImage,
                  onChangePhoto: _showPhotoOptions,
                  onEditName: _editName,
                )
              : const SizedBox.shrink(),
        ],
      ),
      floatingActionButton: AnimatedScale(
        scale: _tab == 0 ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: FloatingActionButton.extended(
          onPressed: _openAddSheet,
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Task'),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: kPrimary.withOpacity(0.15),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_rounded),
            selectedIcon: Icon(Icons.checklist_rounded, color: kPrimary),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: kPrimary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ============================ TASK TILE ============================
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.todo,
    this.onToggle,
    this.onDelete,
    this.onSwiped,
  });
  final Todo todo;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onSwiped;

  @override
  Widget build(BuildContext context) {
    final color = todo.category.color;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: todo.done ? color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: todo.done ? color.withOpacity(0.3) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated checkbox
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: todo.done ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: todo.done
                    ? const Icon(Icons.check_rounded,
                        key: ValueKey('checked'), size: 18, color: Colors.white)
                    : const SizedBox(key: ValueKey('empty')),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: todo.done ? Colors.grey : Colors.black87,
                    decoration: todo.done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                  child: Text(todo.title),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(todo.category.icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      todo.category.label,
                      style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded,
                color: Colors.grey.shade400),
          ),
        ],
      ),
    );

    if (onSwiped == null) return tile;

    return Dismissible(
      key: ObjectKey(todo),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onSwiped!(),
      child: tile,
    );
  }
}

// ============================ EMPTY STATE ============================
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: v, child: child),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimary.withOpacity(0.1),
              ),
              child:
                  const Icon(Icons.task_alt_rounded, size: 64, color: kPrimary),
            ),
            const SizedBox(height: 18),
            const Text('All clear!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Add your first task with the button below',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

// ========================== ADD TASK SHEET ==========================
class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key, required this.onAdd});
  final void Function(String title, TaskCategory category) onAdd;

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final TextEditingController _controller = TextEditingController();
  TaskCategory _selected = TaskCategory.work;

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text, _selected);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('New Task',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'What do you need to do?',
                filled: true,
                fillColor: kBg,
                prefixIcon: const Icon(Icons.edit_rounded, color: kPrimary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: TaskCategory.values.map((c) {
                final selected = c == _selected;
                return GestureDetector(
                  onTap: () => setState(() => _selected = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? c.color : c.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(c.icon,
                            size: 18,
                            color: selected ? Colors.white : c.color),
                        const SizedBox(width: 6),
                        Text(
                          c.label,
                          style: TextStyle(
                            color: selected ? Colors.white : c.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: kMainGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: _submit,
                  child: const Text(
                    'Add Task',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
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

// ============================ NAME DIALOG ============================
class NameDialog extends StatefulWidget {
  const NameDialog({super.key, required this.initial});
  final String initial;

  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Edit your name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          filled: true,
          fillColor: kBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('Save')),
      ],
    );
  }
}

// ============================ PROFILE PAGE ============================
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.todos,
    required this.name,
    required this.profileImage,
    required this.onChangePhoto,
    required this.onEditName,
  });
  final List<Todo> todos;
  final String name;
  final Uint8List? profileImage;
  final VoidCallback onChangePhoto;
  final VoidCallback onEditName;

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      );

  Widget _header(BuildContext context, String level) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 30, 24, 32),
      decoration: const BoxDecoration(
        gradient: kMainGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        children: [
          // Avatar (pops in with a bounce)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: GestureDetector(
              onTap: onChangePhoto,
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: kBg,
                      backgroundImage: profileImage != null
                          ? MemoryImage(profileImage!)
                          : null,
                      child: profileImage == null
                          ? const Icon(Icons.person_rounded,
                              size: 56, color: kPrimary)
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kPink,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onEditName,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_rounded, size: 18, color: Colors.white70),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(level,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _ringCard(double progress, int pending, int total) {
    String message;
    if (total == 0) {
      message = 'Add some tasks to get started!';
    } else if (progress == 1) {
      message = 'Amazing! Everything is done 🎉';
    } else {
      message =
          '$pending task${pending == 1 ? '' : 's'} left. Keep going 💪';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1300),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CustomPaint(
                painter: RingPainter(v),
                child: Center(
                  child: Text(
                    '${(v * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overall Progress',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(message, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryRow(TaskCategory c) {
    final all = todos.where((t) => t.category == c).length;
    final done = todos.where((t) => t.category == c && t.done).length;
    final value = all == 0 ? 0.0 : done / all;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(c.icon, color: c.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c.label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('$done/$all',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor: c.color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(c.color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('By Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          for (final c in TaskCategory.values) _categoryRow(c),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = todos.length;
    final completed = todos.where((t) => t.done).length;
    final pending = total - completed;
    final progress = total == 0 ? 0.0 : completed / total;

    final level = total > 0 && progress == 1
        ? 'Champion 🏆'
        : progress >= 0.5
            ? 'On a roll 🔥'
            : 'Getting started 🌱';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        children: [
          _header(context, level),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                Expanded(
                  child: Entrance(
                    delay: 100,
                    child: StatCard(
                      label: 'Total',
                      value: total,
                      icon: Icons.list_alt_rounded,
                      colors: const [Color(0xFF6C63FF), Color(0xFF9B5DE5)],
                    ),
                  ),
                ),
                Expanded(
                  child: Entrance(
                    delay: 200,
                    child: StatCard(
                      label: 'Completed',
                      value: completed,
                      icon: Icons.check_circle_rounded,
                      colors: const [Color(0xFF2ECC71), Color(0xFF00B894)],
                    ),
                  ),
                ),
                Expanded(
                  child: Entrance(
                    delay: 300,
                    child: StatCard(
                      label: 'Pending',
                      value: pending,
                      icon: Icons.hourglass_top_rounded,
                      colors: const [Color(0xFFFFA64D), Color(0xFFFF6584)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Entrance(delay: 400, child: _ringCard(progress, pending, total)),
          const SizedBox(height: 16),
          Entrance(delay: 550, child: _categoryCard()),
        ],
      ),
    );
  }
}

// ============================ STAT CARD ============================
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
  });
  final String label;
  final int value;
  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 8),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            builder: (context, v, _) => Text(
              '$v',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ],
      ),
    );
  }
}

// ============================ RING PAINTER ============================
class RingPainter extends CustomPainter {
  RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final background = Paint()
      ..color = kBg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(center, radius, background);

    final foreground = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: const [kPrimary, kPink, kPrimary],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, foreground);
  }

  @override
  bool shouldRepaint(RingPainter old) => old.progress != progress;
}