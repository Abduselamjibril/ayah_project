// import 'package:flutter/material.dart';
// import '../data/suwar.dart';

// class MushafHeader extends StatelessWidget {
//   final int surahNumber;

//   const MushafHeader({
//     super.key,
//     required this.surahNumber,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final surahInfo = _getSurahInfo(surahNumber);
//     final isMeccan = _isMeccanSurah(surahNumber);

//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 16),
//       child: Card(
//         elevation: 2,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//               colors: [
//                 Colors.green[50]!,
//                 Colors.green[100]!,
//               ],
//             ),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Column(
//             children: [
//               _buildSurahNumber(context),
//               const SizedBox(height: 12),
//               _buildSurahName(surahInfo),
//               const SizedBox(height: 8),
//               _buildRevelationInfo(isMeccan, surahInfo),
//               if (surahNumber != 9) _buildBismillah(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Map<String, dynamic> _getSurahInfo(int surahNumber) {
//     try {
//       return surah[surahNumber - 1];
//     } catch (e) {
//       return {
//         'name': 'Unknown',
//         'aya': 0,
//       };
//     }
//   }

//   Widget _buildSurahNumber(BuildContext context) {
//     return Container(
//       width: 60,
//       height: 60,
//       decoration: BoxDecoration(
//         color: Colors.green[700],
//         shape: BoxShape.circle,
//       ),
//       child: Center(
//         child: Text(
//           surahNumber.toString(),
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSurahName(Map<String, dynamic> surahInfo) {
//     return Text(
//       surahInfo['name'] ?? 'Unknown',
//       style: TextStyle(
//         fontSize: 28,
//         fontWeight: FontWeight.bold,
//         color: Colors.green[900],
//       ),
//       textDirection: TextDirection.rtl,
//     );
//   }

//   Widget _buildRevelationInfo(bool isMeccan, Map<String, dynamic> surahInfo) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         _buildInfoItem(
//           icon: Icons.location_on,
//           text: isMeccan ? 'Meccan' : 'Medinan',
//         ),
//         const SizedBox(width: 16),
//         _buildInfoItem(
//           icon: Icons.format_list_numbered,
//           text: '${surahInfo['aya'] ?? 0} Verses',
//         ),
//       ],
//     );
//   }

//   Widget _buildInfoItem({required IconData icon, required String text}) {
//     return Row(
//       children: [
//         Icon(
//           icon,
//           size: 16,
//           color: Colors.green[700],
//         ),
//         const SizedBox(width: 4),
//         Text(
//           text,
//           style: TextStyle(
//             fontSize: 14,
//             color: Colors.green[700],
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildBismillah() {
//     return Padding(
//       padding: const EdgeInsets.only(top: 8),
//       child: Text(
//         '﷽',
//         style: TextStyle(
//           fontSize: 24,
//           color: Colors.green[800],
//         ),
//       ),
//     );
//   }

//   bool _isMeccanSurah(int surahNumber) {
//     // Define Medinan surahs
//     const medinanSurahs = {
//       2,
//       3,
//       4,
//       5,
//       8,
//       9,
//       33,
//       47,
//       48,
//       49,
//       57,
//       58,
//       59,
//       60,
//       61,
//       62,
//       63,
//       64,
//       65,
//       66,
//       76,
//       98,
//       99,
//       110
//     };
//     return !medinanSurahs.contains(surahNumber);
//   }
// }
