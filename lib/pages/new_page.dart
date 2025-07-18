// lib/pages/edit_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:noted_pak/pages/camera_screen.dart';

import 'package:noted_pak/widgets/new_tag_dialog.dart';
import 'package:noted_pak/widgets/note_tag.dart';
import 'package:noted_pak/widgets/confirmation_dialog.dart';
import 'package:noted_pak/models/note.dart';
import 'package:noted_pak/change_notifiers/notes_provider.dart';

const Color _primaryBlue = Color(0xFF4285F4);
const Color _lightBorderColor = Color(0xFFE9ECEF);

class NewOrEditNotePage extends StatefulWidget {
  final Map<String, dynamic>? existingNote;
  final bool isReadOnly;
  final String? initialContent;

  const NewOrEditNotePage({
    super.key,
    this.existingNote,
    this.isReadOnly = false,
    this.initialContent,
  });

  @override
  State<NewOrEditNotePage> createState() => _NewOrEditNotePageState();
}

class _NewOrEditNotePageState extends State<NewOrEditNotePage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<String> _tags = [];
  DateTime? _dateCreated;
  DateTime? _dateModified;

  late bool _isEditingMode;
  bool _isOcrProcessing = false;

  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _isStrikethrough = false;

  final List<String> _allExistingUserTags = [
    'Personal Routine', 'Life', 'College', 'Work', 'Health',
    'Finance', 'Travel', 'Ideas', 'Shopping', 'Goals',
    'Hobby', 'Daily',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadExistingNote();
    _setInitialContent();

    if (widget.isReadOnly) {
      _isEditingMode = false;
    } else if (widget.existingNote == null) {
      _isEditingMode = true;
    } else {
      _isEditingMode = false;
    }
  }

  void _initializeControllers() {
    _titleController = TextEditingController();
    _contentController = TextEditingController();
  }

  void _loadExistingNote() {
    if (widget.existingNote != null) {
      _titleController.text = widget.existingNote!['title'] ?? '';
      _contentController.text = widget.existingNote!['content'] ?? '';
      _tags = List<String>.from(widget.existingNote!['tags'] ?? []);

      _dateCreated = _parseDate(widget.existingNote!['dateCreated']);
      _dateModified = _parseDate(widget.existingNote!['dateModified']);

      for (var tag in _tags) {
        if (!_allExistingUserTags.contains(tag)) {
          _allExistingUserTags.add(tag);
        }
      }
    } else {
      _dateCreated = DateTime.now();
      _dateModified = DateTime.now();
    }
  }

  void _setInitialContent() {
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      _contentController.text = widget.initialContent!;
      // Judul TETAP KOSONG, sesuai permintaan
    }
  }

  DateTime? _parseDate(dynamic date) {
    if (date is DateTime) {
      return date;
    } else if (date is String) {
      return DateTime.tryParse(date);
    } else if (date is Timestamp) {
      return date.toDate();
    }
    return null;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }

  void _addTag() async {
    final newTag = await showDialog<String>(
      context: context,
      builder: (context) => NewTagDialog(
        existingTags: _allExistingUserTags,
        currentNoteTags: _tags,
      ),
    );

    if (newTag != null && newTag.isNotEmpty && !_tags.contains(newTag)) {
      setState(() {
        _tags.add(newTag);
        _dateModified = DateTime.now();
        if (!_allExistingUserTags.contains(newTag)) {
          _allExistingUserTags.add(newTag);
        }
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _dateModified = DateTime.now();
    });
  }

  void _saveNote() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return const ConfirmationDialog(
          title: 'Confirm Changes',
          content: 'Are you sure you want to save these changes?',
          confirmButtonText: 'Save',
          cancelButtonText: 'Cancel',
          confirmButtonColor: _primaryBlue,
        );
      },
    );

    if (confirmed != null && confirmed) {
      if (!mounted) return;

      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      Note newOrUpdatedNote = Note(
        id: widget.existingNote != null ? widget.existingNote!['id'] as String? : null,
        title: _titleController.text.isEmpty ? 'Untitled Note' : _titleController.text,
        content: _contentController.text,
        tags: _tags,
        dateCreated: _dateCreated ?? DateTime.now(),
        dateModified: DateTime.now(),
      );

      if (newOrUpdatedNote.id == null) {
        await notesProvider.addNote(newOrUpdatedNote);
        print("Note added to Firebase!");
      } else {
        await notesProvider.updateNote(newOrUpdatedNote);
        print("Note updated in Firebase!");
      }

      Navigator.pop(context);
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return const ConfirmationDialog(
          title: 'Delete Note',
          content: 'Are you sure you want to delete this note?',
          confirmButtonText: 'Delete',
          confirmButtonColor: Colors.red,
          cancelButtonText: 'Cancel',
        );
      },
    ).then((confirmed) async {
      if (confirmed != null && confirmed) {
        if (!mounted) return;

        if (widget.existingNote != null && widget.existingNote!['id'] != null) {
          final notesProvider = Provider.of<NotesProvider>(context, listen: false);
          String noteIdToDelete = widget.existingNote!['id'];

          await notesProvider.deleteNote(noteIdToDelete);
          print("Note deleted from Firebase!");

          // Setelah delete, pop dua kali agar langsung kembali ke home/list
          if (Navigator.canPop(context)) Navigator.of(context).pop(); // Tutup dialog
          if (Navigator.canPop(context)) Navigator.of(context).pop(); // Tutup halaman edit/new
        } else {
          print("Cannot delete: Note has no ID.");
        }
      }
    });
  }

  void _showOcrOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Scan using Camera'),
                onTap: () async {
                  Navigator.pop(bc);
                  await _scanUsingCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Pick from Gallery'),
                onTap: () async {
                  Navigator.pop(bc);
                  await _pickFromGalleryAndRecognizeText();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scanUsingCamera() async {
    if (_isOcrProcessing) return;

    setState(() { _isOcrProcessing = true; });

    // Minta izin kamera
    var status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission denied.')),
        );
      }
      setState(() { _isOcrProcessing = false; });
      return;
    }
    if (status.isPermanentlyDenied) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission permanently denied. Please enable from app settings.'),
            action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
          ),
        );
      }
      setState(() { _isOcrProcessing = false; });
      return;
    }

    try {
      final String? extractedText = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      );

      if (!mounted) return;

      if (extractedText != null && extractedText.isNotEmpty) {
        setState(() {
          _contentController.text = extractedText;
          _dateModified = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text extracted successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text extracted or scan cancelled.')),
        );
      }
    } catch (e) {
      print('Error during camera scan OCR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to scan from camera: $e')),
        );
      }
    } finally {
      setState(() { _isOcrProcessing = false; });
    }
  }

  Future<void> _pickFromGalleryAndRecognizeText() async {
    if (_isOcrProcessing) return;

    setState(() { _isOcrProcessing = true; });

    // Minta izin storage/foto
    var status = await Permission.storage.request(); // Untuk Android < 13
    if (status.isDenied) {
      status = await Permission.photos.request(); // Untuk Android >= 13 & iOS photos
    }

    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage/Photos permission denied.')),
        );
      }
      setState(() { _isOcrProcessing = false; });
      return;
    }
     if (status.isPermanentlyDenied) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage/Photos permission permanently denied. Please enable from app settings.'),
            action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
          ),
        );
      }
      setState(() { _isOcrProcessing = false; });
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (!mounted) return;

      if (image != null) {
        final TextRecognizer textRecognizer = TextRecognizer();
        final InputImage inputImage = InputImage.fromFilePath(image.path);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        textRecognizer.close();

        if (recognizedText.text.isNotEmpty) {
          setState(() {
            _contentController.text = recognizedText.text;
            _dateModified = DateTime.now();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Text extracted successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in the selected image.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected.')),
        );
      }
    } catch (e) {
      print('Error during gallery OCR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image from gallery: $e')),
        );
      }
    } finally {
      setState(() { _isOcrProcessing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNewNote = widget.existingNote == null;
    final bool isInputReadOnly = !_isEditingMode || widget.isReadOnly;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isNewNote
              ? 'New Note'
              : (_isEditingMode ? 'Edit Note' : 'View Note'),
          style: const TextStyle(
            color: _primaryBlue,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Tombol OCR Scanner
          if (_isEditingMode && !widget.isReadOnly)
            _isOcrProcessing
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(color: _primaryBlue),
                  )
                : IconButton(
                    // Ganti icon di sini
                    icon: const Icon(FontAwesomeIcons.solidClipboard, color: _primaryBlue), // Menggunakan FontAwesome
                    // Atau jika tidak FontAwesome, gunakan ini:
                    // icon: const Icon(Icons.receipt_long, color: _primaryBlue),
                    onPressed: _showOcrOptions,
                  ),

          // Tombol Done/Edit
          if (!isNewNote && !_isEditingMode && !widget.isReadOnly)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditingMode = true;
                  _dateModified = DateTime.now();
                });
              },
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: _primaryBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          if (_isEditingMode && !widget.isReadOnly)
            TextButton(
              onPressed: _saveNote,
              child: const Text(
                'Done',
                style: TextStyle(
                  color: _primaryBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Tombol More (dengan Delete Note)
          if (!isNewNote && _isEditingMode && !widget.isReadOnly)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteConfirmationDialog();
                }
              },
              itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Note', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert, color: _primaryBlue),
            ),
        ],
      ),
      body: Column(
        children: [
          // Title Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  readOnly: isInputReadOnly,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Title here..',
                    hintStyle: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400],
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    if (_isEditingMode) {
                      setState(() {
                        _dateModified = DateTime.now();
                      });
                    }
                  },
                ),

                const SizedBox(height: 16),

                if (!isNewNote) ...[
                  Row(
                    children: [
                      Text(
                        'Created',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(_dateCreated ?? DateTime.now()),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Last modified',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(_dateModified ?? DateTime.now()),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // Tags Section
                Row(
                  children: [
                    Text(
                      'Tags',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    if (_isEditingMode && !widget.isReadOnly)
                      ElevatedButton(
                        onPressed: _addTag,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Icon(Icons.add, size: 16),
                      ),
                    const Spacer(),
                    if (_tags.isEmpty && isInputReadOnly)
                      Text(
                        'No tags added',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                if (_tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags
                        .map(
                          (tag) => DotTag(
                            tag: tag,
                            child:
                                (_isEditingMode && !widget.isReadOnly)
                                    ? GestureDetector(
                                        onTap: () => _removeTag(tag),
                                        child: Container(
                                          padding: const EdgeInsets.only(left: 6),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : null,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content Editor
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _contentController,
                        readOnly: isInputReadOnly,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                          fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                          decoration: TextDecoration.combine([
                            if (_isUnderline) TextDecoration.underline,
                            if (_isStrikethrough) TextDecoration.lineThrough,
                          ]),
                        ),
                        decoration: InputDecoration(
                          hintText: 'The..',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          if (_isEditingMode) {
                            setState(() {
                              _dateModified = DateTime.now();
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  // Rich Text Toolbar
                  if (_isEditingMode && !widget.isReadOnly)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: _lightBorderColor),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.undo),
                            color: Colors.grey[600],
                            onPressed: () { /* Implement undo functionality */ },
                          ),
                          IconButton(
                            icon: const Icon(Icons.redo),
                            color: Colors.grey[600],
                            onPressed: () { /* Implement redo functionality */ },
                          ),

                          const SizedBox(width: 8),

                          IconButton(
                            icon: const Icon(Icons.format_bold),
                            color: _isBold ? _primaryBlue : Colors.grey[600],
                            onPressed: () {
                              setState(() {
                                _isBold = !_isBold;
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.format_italic),
                            color: _isItalic ? _primaryBlue : Colors.grey[600],
                            onPressed: () {
                              setState(() {
                                _isItalic = !_isItalic;
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.format_underlined),
                            color: _isUnderline ? _primaryBlue : Colors.grey[600],
                            onPressed: () {
                              setState(() {
                                _isUnderline = !_isUnderline;
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.format_strikethrough),
                            color: _isStrikethrough ? _primaryBlue : Colors.grey[600],
                            onPressed: () {
                              setState(() {
                                _isStrikethrough = !_isStrikethrough;
                              });
                            },
                          ),

                          const Spacer(),

                          IconButton(
                            icon: const Icon(Icons.format_list_bulleted),
                            color: Colors.grey[600],
                            onPressed: () { /* Implement bullet list functionality */ },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Example: 12 June 2024, 14:30
    return '${date.day} ${_getMonthName(date.month)} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}