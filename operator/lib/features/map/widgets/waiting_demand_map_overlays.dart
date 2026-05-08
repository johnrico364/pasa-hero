import 'package:flutter/material.dart';

import 'operator_assignment_action_panel.dart';
import 'waiting_demand_legend.dart';

/// Bottom-right map stack: **waiting demand** legend sits above the **bus assignment**
/// panel (not embedded inside the legend card or cluster bottom sheet).
class WaitingDemandMapOverlays extends StatelessWidget {
  const WaitingDemandMapOverlays({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const WaitingDemandLegend(expandAlignToBottomRight: false),
        const SizedBox(height: 10),
        Padding(
          // Extra left inset so the card does not cover the route polyline / map center.
          padding: const EdgeInsets.only(right: 8, left: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 248),
            child: Material(
              elevation: 6,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.94),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: OperatorAssignmentActionPanel(compact: true),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
