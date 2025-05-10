import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MaterialApp(home: InPersonVisitPage()));
}

class InPersonVisitPage extends StatefulWidget {
  const InPersonVisitPage({super.key});

  @override
  _InPersonVisitPageState createState() => _InPersonVisitPageState();
}

class _InPersonVisitPageState extends State<InPersonVisitPage> {
  String? selectedFacility = 'Sta. Cruz Police Station 3';
  DateTime? selectedDate;
  String? selectedTime;
  DateTime _currentMonth = DateTime.now();

  final List<CalendarEvent> _events = [];

  List<String> _generateTimeSlots(DateTime date) {
    if (date.weekday >= 6) {
      return [
        '9:00 AM - 10:00 AM',
        '11:00 AM - 12:00 PM',
        '2:00 PM - 3:00 PM',
        '4:00 PM - 5:00 PM'
      ];
    } else {
      return [
        '8:00 AM - 9:00 AM',
        '10:00 AM - 11:00 AM',
        '1:00 PM - 2:00 PM',
        '3:00 PM - 4:00 PM',
        '5:00 PM - 6:00 PM'
      ];
    }
  }

  void _previousMonth() => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
  void _nextMonth() => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstDayOffset = firstDay.weekday % 7;

    return [
      ...List.generate(firstDayOffset, (i) => DateTime(firstDay.year, firstDay.month, 0 - i)),
      ...List.generate(lastDay.day, (i) => DateTime(_currentMonth.year, _currentMonth.month, i + 1))
    ];
  }

  void _selectDate(DateTime date) {
    if (date.month != _currentMonth.month || date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) return;
    setState(() {
      selectedDate = date;
      selectedTime = null;
    });
  }

  void _confirmSchedule() {
    if (selectedFacility == null || selectedDate == null || selectedTime == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Confirm Visit Details", style: TextStyle(fontFamily: 'Inter')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow("Facility:", selectedFacility!),
            _buildDetailRow("Date:", DateFormat('MMMM d, y').format(selectedDate!)),
            _buildDetailRow("Time:", selectedTime!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(fontFamily: 'Inter', color: Color(0xFF054D88))),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _events.add(CalendarEvent(
                  date: selectedDate!,
                  time: selectedTime!,
                  title: 'In-person visit',
                  subtitle: selectedFacility!,
                ));
              });
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VisitScheduledScreen(
                    facility: selectedFacility!,
                    date: selectedDate!,
                    time: selectedTime!, 
                    onBackToHome: () {  },
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF054D88),
              foregroundColor: Colors.white,
            ),
            child: const Text("Confirm", style: TextStyle(fontFamily: 'Inter', color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Text(value),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final List<DateTime> daysInMonth = _getDaysInMonth();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 24),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'In-person Visit',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Text('Facility', style: TextStyle(fontFamily: 'Inter', fontSize: 24, color: Color(0xFF054D88))),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF054D88)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: selectedFacility,
                isExpanded: true,
                underline: const SizedBox(),
                items: ['Sta. Cruz Police Station 3', 'Gandara Police Community Precinct', 'Raxabago-Tondo Police Station']
                    .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontFamily: 'Inter'))))
                    .toList(),
                onChanged: (value) => setState(() => selectedFacility = value),
              ),
            ),

            const SizedBox(height: 24),
            const Text('Schedule Date', style: TextStyle(fontFamily: 'Inter', fontSize: 24, color:  Color(0xFF054D88))),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF054D88)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color:  Color(0xFF054D88))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: const Icon(Icons.chevron_left), onPressed: _previousMonth),
                        Text(DateFormat('MMMM y').format(_currentMonth), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) =>
                          SizedBox(width: 32, child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold)))))
                          .toList(),
                    ),
                  ),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 7,
                    children: daysInMonth.map((date) {
                      final isCurrentMonth = date.month == _currentMonth.month;
                      final isSelected = DateUtils.isSameDay(selectedDate, date);
                      final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

                      return GestureDetector(
                        onTap: isCurrentMonth && !isPast ? () => _selectDate(date) : null,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF054D88) : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              date.day > 0 ? date.day.toString() : '',
                              style: TextStyle(
                                color: isCurrentMonth
                                    ? (isPast ? Colors.grey : (isSelected ? Colors.white : Colors.black))
                                    : Colors.transparent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            if (selectedDate != null) ...[
              const SizedBox(height: 24),
              const Text('Available Time Slots', style: TextStyle(fontFamily: 'Inter', fontSize: 24)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _generateTimeSlots(selectedDate!).map((time) => InkWell(
                  onTap: () => setState(() => selectedTime = time),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: selectedTime == time ? const Color(0xFF054D88) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selectedTime == time ? const Color(0xFF054D88) : Colors.grey),
                    ),
                    child: Text(time, style: TextStyle(color: selectedTime == time ? Colors.white : Colors.black, fontFamily: 'Inter')),
                  ),
                )).toList(),
              ),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: ElevatedButton(
                  onPressed: (selectedDate != null && selectedTime != null) ? _confirmSchedule : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF054D88),
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Schedule Visit', style: TextStyle(fontFamily: 'Inter', fontSize: 18, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalendarEvent {
  final DateTime date;
  final String time;
  final String title;
  final String? subtitle;

  CalendarEvent({required this.date, required this.time, required this.title, this.subtitle});
}

class VisitScheduledScreen extends StatelessWidget {
  final String facility;
  final DateTime date;
  final String time;
  final VoidCallback onBackToHome;

  const VisitScheduledScreen({
    super.key,
    required this.facility,
    required this.date,
    required this.time,
    required this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 100, color: Color(0xFF054D88)),
            const SizedBox(height: 24),
            const Text(
              'Visit Scheduled!',
              style: TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'You will get a notification to confirm if your visitation schedule is approved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Facility:', facility),
            _buildDetailRow('Date:', DateFormat('MMMM d, y').format(date)),
            _buildDetailRow('Time:', time),
            const SizedBox(height: 32),
            TextButton.icon(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF054D88)),
              label: const Text('Back to Home', style: TextStyle(color: Color(0xFF054D88))),
              onPressed: onBackToHome,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text(value),
      ],
    ),
  );
}