import 'package:flutter/material.dart';
import 'package:src/widgets/center_info_widget.dart';
import 'package:src/widgets/custom_card_widget.dart';
import 'package:src/widgets/header_widget.dart';

class ProjectInfoScreen extends StatelessWidget {
  const ProjectInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          const HeaderWidget(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: const CustomCard(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.all(26),
                    expandChild: true,
                    child: CenterInfoContent(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
