import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'cc_inpersonvisit.dart';

class CalendarPage extends StatefulWidget {
  final List<CalendarEvent> events;

  const CalendarPage({super.key, required this.events});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selectedDate = DateTime.now();
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final days = <DateTime>[];
    for (var i = 0; i < firstDay.weekday; i++) {
      days.add(firstDay.subtract(Duration(days: firstDay.weekday - i)));
    }
    for (var i = 0; i < lastDay.day; i++) {
      days.add(DateTime(month.year, month.month, i + 1));
    }
    return days;
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return widget.events
        .where((event) =>
            event.date.year == day.year &&
            event.date.month == day.month &&
            event.date.day == day.day)
        .toList();
  }

  List<CalendarEvent> _getEventsForWeek(DateTime day) {
    final startOfWeek = day.subtract(Duration(days: day.weekday));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return widget.events
        .where((event) =>
            event.date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            event.date.isBefore(endOfWeek.add(const Duration(days: 1))))
        .toList();
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  Future<void> _showMonthYearPicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 5, 77, 136),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _currentMonth = DateTime(picked.year, picked.month, 1);
        _selectedDate = DateTime(
            picked.year,
            picked.month,
            _selectedDate.day.clamp(
                1, DateTime(picked.year, picked.month + 1, 0).day));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final todayEvents = _getEventsForDay(_selectedDate);
    final weekEvents = _getEventsForWeek(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 28),
              onPressed: () => _changeMonth(-1),
            ),
            GestureDetector(
              onTap: _showMonthYearPicker,
              child: Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: screenWidth * 0.06,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 28),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (index) {
                    final weekday =
                        DateFormat.E().format(DateTime(2021, 1, 4 + index));
                    return SizedBox(
                      width: 32,
                      child: Text(
                        weekday[0],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: daysInMonth.length,
                  itemBuilder: (context, index) {
                    final day = daysInMonth[index];
                    final isCurrentMonth = day.month == _currentMonth.month;
                    final isSelected = day.day == _selectedDate.day &&
                        day.month == _selectedDate.month &&
                        day.year == _selectedDate.year;
                    final isToday = day.day == DateTime.now().day &&
                        day.month == DateTime.now().month &&
                        day.year == DateTime.now().year;

                    return GestureDetector(
                      onTap: () {
                        if (isCurrentMonth) {
                          setState(() {
                            _selectedDate = day;
                          });
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color.fromARGB(255, 5, 77, 136)
                              : isToday
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            day.day.toString(),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : isCurrentMonth
                                      ? Colors.black
                                      : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Today - ${DateFormat('EEEE, MMMM d').format(_selectedDate)}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (todayEvents.isNotEmpty)
                ...todayEvents.map((event) => _EventItem(
                      time: event.time,
                      title: event.title,
                      subtitle: event.subtitle,
                    ))
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'No events for today',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'This Week',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (weekEvents.isNotEmpty)
                ...weekEvents.map((event) => _EventItem(
                      time:
                          '${DateFormat('EEEE, MMMM d').format(event.date)}\n${event.time}',
                      title: event.title,
                      subtitle: event.subtitle,
                    ))
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'No events this week',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventItem extends StatelessWidget {
  final String time;
  final String title;
  final String? subtitle;

  const _EventItem({
    required this.time,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment:
            subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              time,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
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
}