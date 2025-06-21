import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class ActivityEntryDialog extends StatefulWidget {
  final Function(String) onSave;
  
  const ActivityEntryDialog({
    Key? key,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ActivityEntryDialog> createState() => _ActivityEntryDialogState();
}

class _ActivityEntryDialogState extends State<ActivityEntryDialog> {
  final TextEditingController _activityController = TextEditingController();
  bool _isValid = false;
  
  @override
  void initState() {
    super.initState();
    _activityController.addListener(_validateInput);
  }
  
  @override
  void dispose() {
    _activityController.dispose();
    super.dispose();
  }
  
  void _validateInput() {
    setState(() {
      _isValid = _activityController.text.trim().isNotEmpty;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.black,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.richGold),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Activity',
              style: TextStyle(
                color: AppColors.richGold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _activityController,
              maxLines: 5,
              minLines: 3,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe the activity or service provided...',
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.black,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.richGold),
                ),
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isValid
                      ? () {
                          widget.onSave(_activityController.text.trim());
                          Navigator.of(context).pop();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.richGold,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Save', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
