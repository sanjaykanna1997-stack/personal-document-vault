import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vault_document.dart';
import '../services/vault_service.dart';
import 'vault_gate.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  static const gold = Color(0xFF009B83);
  List<String> members = ['Mine', 'Wife', 'Father', 'Mother'];
  static const categories = [
    'Aadhaar', 'PAN', 'Driving Licence', 'Passport', 'Passport Photo',
    'Voter ID', 'Vehicle RC', 'Insurance', 'Medical', 'Education', 'Other',
  ];

  final _search = TextEditingController();
  final _picker = ImagePicker();
  List<VaultDocument> _documents = [];
  String _memberFilter = 'All';
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _refresh();
  }

  Future<void> _loadMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('sanj_ai_members_v1');
    if (list != null && list.isNotEmpty) {
      if (mounted) setState(() => members = list);
    }
  }

  Future<void> _saveMembers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('sanj_ai_members_v1', members);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final docs = await VaultService.instance.listDocuments();
      if (mounted) setState(() => _documents = docs);
    } catch (e) {
      _message('Could not read the vault: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<VaultDocument> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return _documents.where((doc) {
      final matchesMember = _memberFilter == 'All' || doc.member == _memberFilter;
      final matchesQuery = query.isEmpty ||
          '${doc.name} ${doc.member} ${doc.category}'.toLowerCase().contains(query);
      return matchesMember && matchesQuery;
    }).toList();
  }

  Future<void> _chooseImport({required bool camera}) async {
    if (_busy) return;
    try {
      File? file;
      if (camera) {
        final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 92);
        if (photo == null) return;
        file = File(photo.path);
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final picked = result.files.single;
        if (picked.bytes != null) {
          await _saveImported(picked.name, picked.bytes!);
          return;
        }
        if (picked.path != null) file = File(picked.path!);
      }
      if (file != null) await _saveImported(p.basename(file.path), await file.readAsBytes());
    } catch (e) {
      _message('Import failed: $e');
    }
  }

  Future<void> _saveImported(String name, List<int> bytes) async {
    final details = await _documentDetails(name);
    if (details == null) return;
    setState(() => _busy = true);
    try {
      await VaultService.instance.importBytes(
        name: name,
        member: details.$1,
        category: details.$2,
        bytes: bytes,
      );
      await _refresh();
      _message('$name added to the encrypted vault.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<(String, String)?> _documentDetails(String filename) async {
    String member = members.first;
    String category = _guessCategory(filename);
    return showDialog<(String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        backgroundColor: const Colors.white,
        title: const Text('Save document'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(filename, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: member,
            decoration: const InputDecoration(labelText: 'Family member'),
            items: members.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setDialog(() => member = v ?? member),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: category,
            decoration: const InputDecoration(labelText: 'Document type'),
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setDialog(() => category = v ?? category),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, (member, category)), child: const Text('ENCRYPT & SAVE')),
        ],
      )),
    );
  }

  String _guessCategory(String name) {
    final lower = name.toLowerCase();
    for (final c in categories) {
      if (lower.contains(c.toLowerCase().replaceAll(' ', ''))) return c;
      if (lower.contains(c.toLowerCase())) return c;
    }
    return 'Other';
  }

  Future<void> _openDocument(VaultDocument doc) async {
    try {
      final file = await VaultService.instance.createTemporaryDecryptedCopy(doc);
      await OpenFilex.open(file.path);
      // The temporary cleartext file is removed after the viewer returns.
      if (await file.exists()) await file.delete();
    } catch (e) {
      _message('Unable to open document: $e');
    }
  }

  Future<void> _deleteDocument(VaultDocument doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Colors.white,
        title: const Text('Delete document?'),
        content: Text('Permanently remove ${doc.name} from this device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (confirm == true) {
      await VaultService.instance.deleteDocument(doc);
      await _refresh();
    }
  }

  void _lock() {
    VaultService.instance.lock();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const VaultGate()),
      (_) => false,
    );
  }

  Future<void> _manageMembers() async {
    final textController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Family Members'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textController,
                        decoration: const InputDecoration(hintText: 'Member name (e.g. Son)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: gold),
                      onPressed: () async {
                        final val = textController.text.trim();
                        if (val.isEmpty || members.contains(val)) return;
                        setState(() => members.add(val));
                        setDialogState(() {});
                        await _saveMembers();
                        textController.clear();
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: members.length,
                    itemBuilder: (ctx, idx) {
                      final m = members[idx];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: gold.withOpacity(0.12),
                          child: Text(m.isNotEmpty ? m[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, color: gold, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                          onPressed: () async {
                            if (members.length <= 1) {
                              _message('You need at least one member.');
                              return;
                            }
                            setState(() {
                              members.removeAt(idx);
                              if (_memberFilter == m) _memberFilter = 'All';
                            });
                            setDialogState(() {});
                            await _saveMembers();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docs = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.shield_outlined, color: gold), SizedBox(width: 10), Text('Family Vault', style: TextStyle(fontWeight: FontWeight.bold))]),
        actions: [
          IconButton(tooltip: 'Manage members', onPressed: _manageMembers, icon: const Icon(Icons.group_outlined, color: gold)),
          IconButton(tooltip: 'Lock vault', onPressed: _lock, icon: const Icon(Icons.lock_outline, color: gold)),
        ],
      ),
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [Color(0xFF071536), Color(0xFF0D2148)]),
              border: Border.all(color: const Color(0xFFB9E4DB)),
            ),
            child: Row(children: [
              const Icon(Icons.offline_pin, color: gold, size: 30),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Private. Encrypted. Offline-ready.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('${_documents.length} saved documents · Stored on this device', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search Aadhaar, PAN, Mine, passport…',
              prefixIcon: const Icon(Icons.search, color: gold),
              suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close)),
              filled: true, fillColor: const Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          'All', ...members,
        ].map((m) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(label: Text(m), selected: _memberFilter == m, onSelected: (_) => setState(() => _memberFilter = m), selectedColor: gold.withOpacity(.22)),
        )).toList())),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Expanded(child: Text('YOUR DOCUMENTS', style: TextStyle(color: gold, letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 11))),
            Text('${docs.length} FILES', style: const TextStyle(color: Color(0xFF7A8799), fontSize: 10)),
          ]),
        ),
        const SizedBox(height: 6),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : docs.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.folder_open, color: gold, size: 48),
                const SizedBox(height: 12),
                Text(_documents.isEmpty ? 'Your secure vault is empty' : 'No matching documents', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Add a PDF or take a document photo to get started.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7A8799))),
              ])))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: docs.length,
                itemBuilder: (context, index) => _documentTile(docs[index]),
              )),
      ])),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: const Colors.white,
          builder: (context) => SafeArea(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              ListTile(leading: const Icon(Icons.upload_file, color: gold), title: const Text('Import PDF or image'), subtitle: const Text('Choose a file from this device'), onTap: () { Navigator.pop(context); _chooseImport(camera: false); }),
              ListTile(leading: const Icon(Icons.document_scanner_outlined, color: gold), title: const Text('Scan with camera'), subtitle: const Text('Capture a document photo'), onTap: () { Navigator.pop(context); _chooseImport(camera: true); }),
            ]),
          )),
        ),
        backgroundColor: gold,
        foregroundColor: Colors.black,
        icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
        label: const Text('ADD DOCUMENT'),
      ),
    );
  }

  Widget _documentTile(VaultDocument doc) {
    final isPdf = doc.name.toLowerCase().endsWith('.pdf');
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        onTap: () => _openDocument(doc),
        leading: Container(
          width: 44, height: 48,
          decoration: BoxDecoration(color: gold.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: gold),
        ),
        title: Text(doc.category, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${doc.member} · ${doc.name}\n${_formatBytes(doc.sizeBytes)} · ${doc.addedAt.toLocal().toString().split('.').first}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7A8799), height: 1.5, fontSize: 11)),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'open') _openDocument(doc);
            if (value == 'delete') _deleteDocument(doc);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'open', child: Text('Open document')),
            PopupMenuItem(value: 'delete', child: Text('Delete document')),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
