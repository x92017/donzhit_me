import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../constants/dropdown_options.dart';
import '../models/traffic_report.dart';
import '../providers/report_provider.dart';
import '../providers/settings_provider.dart';
import '../services/places_service.dart';
import '../widgets/donzhit_logo.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _injuriesController = TextEditingController();
  final _cityController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  final Set<String> _selectedRoadUsages = {};
  final Set<String> _selectedEventTypes = {};
  String? _selectedState;
  String? _selectedCity;
  bool _retainMediaMetadata = true;

  final List<XFile> _selectedMedia = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _loadDefaultState();
  }

  void _loadDraft() {
    final provider = context.read<ReportProvider>();
    final draft = provider.currentDraft;
    if (draft != null) {
      _titleController.text = draft.title;
      _descriptionController.text = draft.description;
      _injuriesController.text = draft.injuries;
      _selectedDateTime = draft.dateTime;
      _selectedRoadUsages.addAll(draft.roadUsages);
      _selectedEventTypes.addAll(draft.eventTypes);
      _selectedState = draft.state;
      _selectedCity = draft.city.isNotEmpty ? draft.city : null;
      _cityController.text = draft.city;
      _retainMediaMetadata = draft.retainMediaMetadata;
    }
  }

  void _loadDefaultState() {
    final settings = context.read<SettingsProvider>();
    if (_selectedState == null && settings.defaultState.isNotEmpty) {
      _selectedState = settings.defaultState;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _injuriesController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Column(
          children: [
            // Black header with logo and title
            Container(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 11, top: 2),
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: SafeArea(
                bottom: false,
                minimum: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const DonzHitLogoHorizontal(height: 62),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.save_outlined, color: Colors.white),
                          onPressed: _saveDraft,
                          tooltip: 'Save Draft',
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear_all, color: Colors.white),
                          onPressed: _clearForm,
                          tooltip: 'Clear Form',
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Center(
                      child: Text(
                        'Report Incident',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Form content
            Expanded(
              child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              _buildHeaderCard(),
              const SizedBox(height: 24),

              // Title Field
              _buildSectionTitle('Incident Details'),
              const SizedBox(height: 12),
              _buildTitleField(),
              const SizedBox(height: 16),

              // Description Field
              _buildDescriptionField(),
              const SizedBox(height: 16),

              // Date/Time Field
              _buildDateTimeField(),
              const SizedBox(height: 24),

              // Classification Section
              _buildSectionTitle('Classification'),
              const SizedBox(height: 12),

              // Road Usage Multi-Select
              _buildRoadUsageSelector(),
              const SizedBox(height: 16),

              // Event Type Multi-Select
              _buildEventTypeSelector(),
              const SizedBox(height: 16),

              // State Dropdown
              _buildStateDropdown(),
              const SizedBox(height: 16),

              // City Autocomplete (only shows when state is selected)
              if (_selectedState != null) _buildCityAutocomplete(),
              if (_selectedState != null) const SizedBox(height: 24),
              if (_selectedState == null) const SizedBox(height: 8),

              // Additional Info Section
              _buildSectionTitle('Additional Information'),
              const SizedBox(height: 12),

              // Injuries Field
              _buildInjuriesField(),
              const SizedBox(height: 24),

              // Media Upload Section
              _buildSectionTitle('Upload Media'),
              const SizedBox(height: 12),
              _buildMediaUpload(),
              const SizedBox(height: 32),

              // Submit Button
              _buildSubmitButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.report_problem,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report a Traffic Violation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fill out the form below with details about the incident',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withValues(alpha: 0.8),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Title',
        hintText: 'Enter a brief title for the incident',
        prefixIcon: Icon(Icons.title),
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a title';
        }
        return null;
      },
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description',
        hintText: 'Describe what happened in detail',
        prefixIcon: Icon(Icons.description),
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: 4,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a description';
        }
        return null;
      },
    );
  }

  Widget _buildDateTimeField() {
    return InkWell(
      onTap: _selectDateTime,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date/Time',
          prefixIcon: Icon(Icons.calendar_today),
          border: OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMMM d, yyyy - h:mm a').format(_selectedDateTime),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadUsageSelector() {
    return FormField<Set<String>>(
      initialValue: _selectedRoadUsages,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select at least one road usage type';
        }
        return null;
      },
      builder: (state) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: 'Road Usage (select all that apply)',
            prefixIcon: const Icon(Icons.directions_car),
            border: const OutlineInputBorder(),
            errorText: state.errorText,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: DropdownOptions.roadUsageTypes.map((type) {
              final isSelected = _selectedRoadUsages.contains(type);
              return FilterChip(
                label: Text(type),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedRoadUsages.add(type);
                    } else {
                      _selectedRoadUsages.remove(type);
                    }
                  });
                  state.didChange(_selectedRoadUsages);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEventTypeSelector() {
    return FormField<Set<String>>(
      initialValue: _selectedEventTypes,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select at least one event type';
        }
        return null;
      },
      builder: (state) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: 'Event Type (select all that apply)',
            prefixIcon: const Icon(Icons.warning_amber),
            border: const OutlineInputBorder(),
            errorText: state.errorText,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: DropdownOptions.eventTypes.map((type) {
              final isSelected = _selectedEventTypes.contains(type);
              return FilterChip(
                label: Text(type),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedEventTypes.add(type);
                    } else {
                      _selectedEventTypes.remove(type);
                    }
                  });
                  state.didChange(_selectedEventTypes);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildStateDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedState,
      decoration: const InputDecoration(
        labelText: 'State/Province',
        prefixIcon: Icon(Icons.location_on),
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      items: DropdownOptions.selectableStatesAndProvinces
          .map((state) => DropdownMenuItem(
                value: state,
                child: Text(state),
              ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedState = value;
          // Clear city when state changes
          _selectedCity = null;
          _cityController.clear();
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a state or province';
        }
        return null;
      },
    );
  }

  Widget _buildCityAutocomplete() {
    if (_selectedState == null) return const SizedBox.shrink();

    return _ReportCityAutocomplete(
      controller: _cityController,
      selectedState: _selectedState!,
      onCitySelected: (city) {
        setState(() {
          _selectedCity = city;
        });
      },
      onCleared: () {
        setState(() {
          _selectedCity = null;
        });
      },
    );
  }

  Widget _buildInjuriesField() {
    return TextFormField(
      controller: _injuriesController,
      decoration: const InputDecoration(
        labelText: 'Any Injuries',
        hintText: 'Describe any injuries that occurred (or "None")',
        prefixIcon: Icon(Icons.healing),
        border: OutlineInputBorder(),
      ),
      maxLines: 2,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please describe any injuries (or enter "None")';
        }
        return null;
      },
    );
  }

  Widget _buildMediaUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_upload,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload Photos or Videos',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Supported formats: JPG, PNG, MP4, MOV',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.folder),
                      label: const Text('Files'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Privacy toggle for media metadata
                SwitchListTile(
                  title: const Text('Retain media location & date data'),
                  subtitle: Text(
                    _retainMediaMetadata
                        ? 'GPS coordinates and timestamps from photos/videos will be stored'
                        : 'GPS coordinates and timestamps will be removed for privacy',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  value: _retainMediaMetadata,
                  onChanged: (value) {
                    setState(() {
                      _retainMediaMetadata = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
        ),
        if (_selectedMedia.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Selected Files (${_selectedMedia.length})',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedMedia.length,
              itemBuilder: (context, index) {
                final file = _selectedMedia[index];
                return _buildMediaThumbnail(file, index);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMediaThumbnail(XFile file, int index) {
    final isVideo = file.name.toLowerCase().endsWith('.mp4') ||
        file.name.toLowerCase().endsWith('.mov');

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isVideo
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam, color: Colors.grey[600]),
                          const SizedBox(height: 4),
                          Text(
                            file.name,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : kIsWeb
                      ? FutureBuilder<Widget>(
                          future: _buildWebImage(file),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return snapshot.data!;
                            }
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        )
                      : Image.file(
                          File(file.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.image,
                            color: Colors.grey[600],
                          ),
                        ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeMedia(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Widget> _buildWebImage(XFile file) async {
    final bytes = await file.readAsBytes();
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Icon(
        Icons.image,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Submitting...'),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send),
                  SizedBox(width: 8),
                  Text(
                    'Submit Report',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (time != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _selectedMedia.add(image);
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedMedia.addAll(images);
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _selectedMedia.addAll(
          result.files
              .where((f) => f.path != null)
              .map((f) => XFile(f.path!)),
        );
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
    });
  }

  Future<void> _saveDraft() async {
    final report = _createReport();
    final provider = context.read<ReportProvider>();
    await provider.saveDraft(report);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Form'),
        content: const Text('Are you sure you want to clear all fields?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _injuriesController.clear();
      _cityController.clear();
      _selectedDateTime = DateTime.now();
      _selectedRoadUsages.clear();
      _selectedEventTypes.clear();
      _selectedState = null;
      _selectedCity = null;
      _retainMediaMetadata = true;
      _selectedMedia.clear();
    });

    context.read<ReportProvider>().clearDraft();
  }

  TrafficReport _createReport() {
    return TrafficReport(
      title: _titleController.text,
      description: _descriptionController.text,
      dateTime: _selectedDateTime,
      roadUsages: _selectedRoadUsages.toList(),
      eventTypes: _selectedEventTypes.toList(),
      state: _selectedState ?? '',
      city: _selectedCity ?? '',
      injuries: _injuriesController.text,
      retainMediaMetadata: _retainMediaMetadata,
      mediaFiles: _selectedMedia
          .map((f) => MediaFile(
                name: f.name,
                path: f.path,
                type: f.name.toLowerCase().endsWith('.mp4') ||
                        f.name.toLowerCase().endsWith('.mov')
                    ? MediaType.video
                    : MediaType.image,
                size: 0,
              ))
          .toList(),
    );
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final report = _createReport();
    final provider = context.read<ReportProvider>();

    // Convert XFiles to Files for non-web platforms
    List<File>? files;
    if (!kIsWeb && _selectedMedia.isNotEmpty) {
      files = _selectedMedia.map((f) => File(f.path)).toList();
    }

    final success = await provider.submitReport(report, files: files);

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to submit report'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _submitReport,
            ),
          ),
        );
      }
    }
  }
}

/// Custom city autocomplete widget that filters by selected state
class _ReportCityAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String selectedState;
  final Function(String) onCitySelected;
  final VoidCallback onCleared;

  const _ReportCityAutocomplete({
    required this.controller,
    required this.selectedState,
    required this.onCitySelected,
    required this.onCleared,
  });

  @override
  State<_ReportCityAutocomplete> createState() => _ReportCityAutocompleteState();
}

class _ReportCityAutocompleteState extends State<_ReportCityAutocomplete> {
  List<CityPrediction> _predictions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  bool _isSelecting = false; // Flag to prevent search when selecting
  Timer? _debounceTimer;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();

    // Skip search if we're programmatically setting text after selection
    if (_isSelecting) {
      _isSelecting = false;
      return;
    }

    final query = widget.controller.text;

    if (query.isEmpty) {
      setState(() {
        _predictions = [];
        _showSuggestions = false;
      });
      _removeOverlay();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchCities(query);
    });
  }

  Future<void> _searchCities(String query) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final results = await PlacesService.searchCities(query, widget.selectedState);

    if (!mounted) return;

    setState(() {
      _predictions = results;
      _isLoading = false;
      _showSuggestions = results.isNotEmpty;
    });

    if (_showSuggestions) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _predictions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final prediction = _predictions[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(prediction.mainText),
                    subtitle: Text(prediction.secondaryText),
                    onTap: () => _selectCity(prediction),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectCity(CityPrediction prediction) {
    // Remove listener to prevent triggering a new search when setting text
    widget.controller.removeListener(_onTextChanged);

    widget.controller.text = prediction.mainText;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );

    // Re-add listener after text is set
    widget.controller.addListener(_onTextChanged);

    widget.onCitySelected(prediction.mainText);
    _removeOverlay();
    _focusNode.unfocus(); // Remove focus to dismiss keyboard
    setState(() {
      _showSuggestions = false;
      _predictions = [];
    });
  }

  void _clearCity() {
    widget.controller.clear();
    widget.onCleared();
    _removeOverlay();
    setState(() {
      _showSuggestions = false;
      _predictions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: 'City (Optional)',
          hintText: 'Search for a city in ${widget.selectedState}',
          prefixIcon: const Icon(Icons.location_city),
          border: const OutlineInputBorder(),
          suffixIcon: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearCity,
                    )
                  : null,
        ),
      ),
    );
  }
}
