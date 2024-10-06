import 'package:flutter/material.dart';
import 'package:src/widgets/custom_card_widget.dart';
import 'package:src/widgets/header_widget.dart';

class ProjectInfoScreen extends StatelessWidget {
  const ProjectInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        children: [
          Expanded(
            flex: 75,
            child: Column(
              children: [
                const HeaderWidget(),
                Expanded(
                  child: CustomCard(
                    child: projectTeamWidget(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget projectTeamWidget() {
    return Center(
      //TODO https://support.freepik.com/s/article/Attribution-How-when-and-where?language=en_US&_gl=1*wnybt3*_gcl_au*ODYwMzg4MTAzLjE3MjgwNzY1NDE.*_ga*MTk1NzQyNTgyNy4xNzI4MDc2NTQy*_ga_18B6QPTJPC*MTcyODA3NjU0MS4xLjEuMTcyODA3NjU2MC40MS4wLjA.*_ga_QWX66025LC*MTcyODA3NjU0Mi4xLjEuMTcyODA3NjU2MS40MS4wLjA.*_ga_Q29FZ8F7H4*MTcyODA3NjU0Mi4xLjEuMTcyODA3NjU2MC4wLjAuMA..
      child: Text('This is the Info Screen!'),
    );
  }
}
