import 'package:src/model/team_member_model.dart';

class TeamMemberData {
  // Shared placeholder until individual portraits are added (682×1024).
  static const String _placeholder =
      'assets/images/team_member_placeholder.png';
  static const String _linkedinUrl = 'https://www.linkedin.com/in/';

  final List<TeamMember> members = const [
    TeamMember(
      name: 'Dr. M. Kamran Saleem',
      role: 'Project Lead',
      imagePath: _placeholder,
      linkedInUrl: '${_linkedinUrl}mksaleemsrc',
    ),
    TeamMember(
      name: 'Muhammad Junaid Qamar',
      role: 'Computer Scientist',
      imagePath: _placeholder,
      linkedInUrl: '${_linkedinUrl}MuhammadJunaidQamar',
    ),
    TeamMember(
      name: 'Team Member',
      role: 'Ground Station',
      imagePath: _placeholder,
      linkedInUrl: '${_linkedinUrl}MuhammadJunaidQamar',
    ),
    TeamMember(
      name: 'Team Member',
      role: 'Backend / Telemetry',
      imagePath: _placeholder,
      linkedInUrl: '${_linkedinUrl}MuhammadJunaidQamar',
    ),
    TeamMember(
      name: 'Team Member',
      role: 'Mechanical / Payload',
      imagePath: _placeholder,
      linkedInUrl: '${_linkedinUrl}MuhammadJunaidQamar',
    ),
    TeamMember(
      name: 'Team Member',
      role: 'Testing / Data',
      imagePath: _placeholder,
      linkedInUrl: '${_linkedinUrl}MuhammadJunaidQamar',
    ),
  ];
}
