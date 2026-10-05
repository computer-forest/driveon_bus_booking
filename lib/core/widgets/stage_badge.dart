import 'package:flutter/material.dart';
import '../../data/models.dart';
import 'status_badge.dart';

/// Label and tone for a booking's lifecycle stage, shared by the customer
/// and admin screens so a stage reads the same everywhere.
(String, StatusTone) stageDisplay(BookingStage stage) {
  switch (stage) {
    case BookingStage.requested:
      return ('Requested', StatusTone.warning);
    case BookingStage.costConfirmed:
      return ('Cost set', StatusTone.warning);
    case BookingStage.confirmed:
      return ('Confirmed', StatusTone.info);
    case BookingStage.inTrip:
      return ('In trip', StatusTone.warning);
    case BookingStage.completed:
      return ('Completed', StatusTone.warning);
    case BookingStage.settled:
      return ('Settled', StatusTone.success);
  }
}

class StageBadge extends StatelessWidget {
  const StageBadge(this.stage, {super.key});

  final BookingStage stage;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = stageDisplay(stage);
    return StatusBadge(label: label, tone: tone);
  }
}
