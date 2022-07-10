import 'package:flutter/material.dart';
import 'package:yours_app/widgets/calendar/DateUtils.dart';
import 'package:yours_app/widgets/calendar/CalendarTile.dart';
import 'package:yours_app/widgets/calendar/GestureDetector.dart';

class Calendar extends StatefulWidget {
  final DateTime currentDate;
  final void Function(DateTime) setCurrentDate;
  final VoidCallback toggleShowingContent;
  bool _hasDateChanged = true;

  Calendar(
      {Key? key,
      required this.currentDate,
      required this.setCurrentDate,
      required this.toggleShowingContent})
      : super(key: key);

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  late String _monthDisplay;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _monthDisplay = Utils.formatMonth(widget.currentDate);
    _month = DateTime(widget.currentDate.year, widget.currentDate.month);
  }

  Widget get nameAndIconRow {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: previousYear,
          icon: const Icon(Icons.keyboard_double_arrow_left),
        ),
        IconButton(
          onPressed: previousMonth,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(_monthDisplay,
              style: const TextStyle(fontSize: 20.0),
              textAlign: TextAlign.center),
        ),
        IconButton(
          onPressed: nextMonth,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          onPressed: nextYear,
          icon: const Icon(Icons.keyboard_double_arrow_right),
        )
      ],
    );
  }

  Widget get calendarGridView {
    return SimpleGestureDetector(
      onSwipeLeft: nextMonth,
      onSwipeRight: previousMonth,
      swipeConfig: const SimpleSwipeConfig(
        horizontalThreshold: 40.0,
        swipeDetectionMoment: SwipeDetectionMoment.onUpdate,
      ),
      child: Column(children: <Widget>[
        GridView.count(
          childAspectRatio: 1.5,
          primary: false,
          shrinkWrap: true,
          crossAxisCount: 7,
          children: calendarBuilder(),
        ),
      ]),
    );
  }

  List<Widget> calendarBuilder() {
    List<Widget> dayWidgets = [];
    DateTime now = DateTime.now();

    for (var day in Utils.weekdays) {
      dayWidgets.add(
        CalendarTile(
            date: now,
            currentDate: widget.currentDate,
            dayOfWeek: day,
            isHeader: true,
            inDisplayedMonth: true,
            onDateSelected: null),
      );
    }

    bool monthStarted = false;
    bool monthEnded = false;

    final monthStart = Utils.firstDayOfMonth(_month);
    final monthEnd = Utils.lastDayOfMonth(_month);
    final calendarDays = Utils.daysInRange(
        Utils.firstDayOfWeek(monthStart), Utils.lastDayOfWeek(monthEnd));

    for (var day in calendarDays) {
      if (day.hour > 0) {
        day = day.toLocal();
        day = day.subtract(Duration(hours: day.hour));
      }

      if (monthStarted && day.day == 01) {
        monthEnded = true;
      }

      if (Utils.isFirstDayOfMonth(day)) {
        monthStarted = true;
      }

      dayWidgets.add(
        CalendarTile(
            date: day,
            currentDate: widget.currentDate,
            dayOfWeek: Utils.weekdays[day.weekday % 7],
            isHeader: false,
            inDisplayedMonth: monthStarted && !monthEnded,
            onDateSelected: () {
              widget.setCurrentDate(day);
              setNewMonth(day);
              widget.toggleShowingContent();
            }),
      );
    }
    return dayWidgets;
  }

  @override
  Widget build(BuildContext context) {
    updateIfDateChanged();
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: 15),
        nameAndIconRow,
        calendarGridView
      ],
    );
  }

  void updateIfDateChanged() {
    if (widget._hasDateChanged) {
      widget._hasDateChanged = false;
      setNewMonth(widget.currentDate);
    }
  }

  void nextMonth() {
    setNewMonth(Utils.nextMonth(_month));
  }

  void previousMonth() {
    setNewMonth(Utils.previousMonth(_month));
  }

  void nextYear() {
    setNewMonth(Utils.nextYear(_month));
  }

  void previousYear() {
    setNewMonth(Utils.previousYear(_month));
  }

  void setNewMonth(DateTime newMonth) {
    setState(() {
      _month = newMonth;
      _monthDisplay = Utils.formatMonth(_month);
    });
  }
}
