import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// الدالة الرئيسية التي تشغل التطبيق
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PrismApp());
}

/// [PrismTask] نموذج البيانات الذي يمثل كل بطاقة تصميم في التطبيق
class PrismTask {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final File? imageFile;
  final double cardHeight;
  bool isLiked;
  bool isDeleted; // للتحقق مما إذا كانت البطاقة في سلة المحذوفات

  PrismTask({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.imageFile,
    required this.cardHeight,
    this.isLiked = false,
    this.isDeleted = false,
  });

  // تحويل البيانات إلى صيغة JSON لتخزينها محلياً
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'filePath': imageFile?.path,
      'cardHeight': cardHeight,
      'isLiked': isLiked,
      'isDeleted': isDeleted,
    };
  }

  // إعادة بناء الكائن من صيغة JSON المخزنة
  factory PrismTask.fromJson(Map<String, dynamic> json) {
    return PrismTask(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      imageFile: json['filePath'] != null ? File(json['filePath']) : null,
      cardHeight: (json['cardHeight'] as num).toDouble(),
      isLiked: json['isLiked'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
    );
  }
}

/// [PrismApp] التطبيق الأساسي
class PrismApp extends StatelessWidget {
  const PrismApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prism App',
      theme: ThemeData.dark(),
      home: const FeedScreen(),
    );
  }
}

/// [FeedScreen] الشاشة الرئيسية لعرض البطاقات مع البحث وسلة المحذوفات
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const String _storageKey = 'prism_tasks_key';
  List<PrismTask> _tasks = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  // متغيرات ميزة البحث
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasksFromStorage();
  }

  // تحميل البيانات من ذاكرة الهاتف
  Future<void> _loadTasksFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJsonString = prefs.getString(_storageKey);

    if (tasksJsonString != null && tasksJsonString.isNotEmpty) {
      final List<dynamic> decodedList = jsonDecode(tasksJsonString);
      setState(() {
        _tasks = decodedList.map((item) => PrismTask.fromJson(item)).toList();
        _isLoading = false;
      });
    } else {
      // إدراج بيانات افتراضية أولية
      setState(() {
        _tasks = [
          PrismTask(
            id: '1',
            title: 'واجهة زجاجية ثلاثية الأبعاد',
            description: 'تصميم Glassmorphic حديث يبرز التفاصيل الفنية.',
            imageUrl: 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=600',
            cardHeight: 220,
          ),
        ];
        _isLoading = false;
      });
      _saveTasksToStorage();
    }
  }

  // حفظ القائمة في ذاكرة الهاتف
  Future<void> _saveTasksToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = _tasks.map((t) => t.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  // نقل البطاقة إلى سلة المحذوفات
  void _moveToTrash(PrismTask task) {
    setState(() {
      task.isDeleted = true;
    });
    _saveTasksToStorage();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نقل "${task.title}" إلى سلة المحذوفات 🗑️'),
        action: SnackBarAction(
          label: 'تراجع',
          textColor: Colors.purpleAccent,
          onPressed: () {
            setState(() {
              task.isDeleted = false;
            });
            _saveTasksToStorage();
          },
        ),
      ),
    );
  }

  // تبديل حالة الإعجاب
  void _toggleLike(String id) {
    setState(() {
      final task = _tasks.firstWhere((item) => item.id == id);
      task.isLiked = !task.isLiked;
    });
    _saveTasksToStorage();
  }

  @override
  Widget build(BuildContext context) {
    // تصفية البطاقات النشطة وغير المحذوفة
    final activeTasks = _tasks.where((t) => !t.isDeleted).toList();

    // تطبيق البحث الفوري في العنوان أو الوصف
    final filteredTasks = activeTasks.where((task) {
      final query = _searchQuery.toLowerCase().trim();
      return task.title.toLowerCase().contains(query) ||
             task.description.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'ابحث في التصاميم...',
                  hintStyle: TextStyle(color: Colors.white50),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : const Text('Prism Feed', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TrashScreen(
                    allTasks: _tasks,
                    onUpdate: () {
                      setState(() {});
                      _saveTasksToStorage();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : activeTasks.isEmpty
              ? const Center(
                  child: Text('لا توجد بطاقات حالياً! ✨', style: TextStyle(color: Colors.white70, fontSize: 16)),
                )
              : filteredTasks.isEmpty
                  ? const Center(
                      child: Text('لا توجد نتائج تطابق بحثك 🔍', style: TextStyle(color: Colors.white50, fontSize: 16)),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];

                          return Dismissible(
                            key: Key(task.id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _moveToTrash(task),
                            background: Container(
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withAlpha(180),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 30),
                            ),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PinDetailsScreen(
                                      task: task,
                                      onLikeToggle: () => _toggleLike(task.id),
                                      onDelete: () {
                                        Navigator.pop(context);
                                        _moveToTrash(task);
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(20),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withAlpha(30)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: task.imageFile != null && task.imageFile!.existsSync()
                                              ? Image.file(task.imageFile!, fit: BoxFit.cover, width: double.infinity)
                                              : Image.network(task.imageUrl ?? '', fit: BoxFit.cover, width: double.infinity),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  task.title,
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                  maxLines: 1,
                                                ),
                                              ),
                                              if (task.isLiked)
                                                const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

/// [TrashScreen] شاشة سلة المحذوفات مع البحث وإفراغ الكل
class TrashScreen extends StatefulWidget {
  final List<PrismTask> allTasks;
  final VoidCallback onUpdate;

  const TrashScreen({super.key, required this.allTasks, required this.onUpdate});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  void _showClearAllConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E30),
          title: const Text('تأكيد الإفراغ', style: TextStyle(color: Colors.white)),
          content: const Text('هل أنت متأكد من حذف جميع العناصر في سلة المحذوفات نهائياً؟', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() {
                  widget.allTasks.removeWhere((t) => t.isDeleted);
                });
                widget.onUpdate();
              },
              child: const Text('حذف الكل', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final deletedTasks = widget.allTasks.where((t) => t.isDeleted).toList();
    final filteredTasks = deletedTasks.where((t) {
      final query = _searchQuery.toLowerCase().trim();
      return t.title.toLowerCase().contains(query) || t.description.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'ابحث في السلة...', border: InputBorder.none),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : const Text('سلة المحذوفات 🗑️', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              _searchQuery = '';
              _searchController.clear();
            }),
          ),
          if (deletedTasks.isNotEmpty && !_isSearching)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              onPressed: () => _showClearAllConfirmationDialog(context),
            ),
        ],
      ),
      body: deletedTasks.isEmpty
          ? const Center(child: Text('سلة المحذوفات فارغة ✨', style: TextStyle(color: Colors.white70)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredTasks.length,
              itemBuilder: (context, index) {
                final task = filteredTasks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: task.imageFile != null && task.imageFile!.existsSync()
                          ? Image.file(task.imageFile!, width: 50, height: 50, fit: BoxFit.cover)
                          : Image.network(task.imageUrl ?? '', width: 50, height: 50, fit: BoxFit.cover),
                    ),
                    title: Text(task.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(task.description, style: const TextStyle(color: Colors.white70), maxLines: 1),
                    trailing: IconButton(
                      icon: const Icon(Icons.restore_from_trash_rounded, color: Colors.greenAccent),
                      onPressed: () {
                        setState(() => task.isDeleted = false);
                        widget.onUpdate();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// [PinDetailsScreen] شاشة تفاصيل البطاقة مع إمكانية المشاركة
class PinDetailsScreen extends StatefulWidget {
  final PrismTask task;
  final VoidCallback onLikeToggle;
  final VoidCallback onDelete;

  const PinDetailsScreen({super.key, required this.task, required this.onLikeToggle, required this.onDelete});

  @override
  State<PinDetailsScreen> createState() => _PinDetailsScreenState();
}

class _PinDetailsScreenState extends State<PinDetailsScreen> {
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.task.isLiked;
  }

  Future<void> _shareDesign() async {
    await Share.share('تصميم من Prism:\nالعنوان: ${widget.task.title}\nالوصف: ${widget.task.description}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: widget.task.imageFile != null && widget.task.imageFile!.existsSync()
                      ? Image.file(widget.task.imageFile!, fit: BoxFit.contain, width: double.infinity)
                      : Image.network(widget.task.imageUrl ?? '', fit: BoxFit.contain, width: double.infinity),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.task.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.redAccent : Colors.white),
                        onPressed: () {
                          setState(() => _isLiked = !_isLiked);
                          widget.onLikeToggle();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(widget.task.description, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _shareDesign,
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      label: const Text('مشاركة التصميم', style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withAlpha(80))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
