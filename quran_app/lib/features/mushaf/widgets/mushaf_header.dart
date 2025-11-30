// import 'package:flutter/material.dart';
// import '../data/suwar.dart';

// class HeaderWidget extends StatelessWidget {
//   final int suraNumber;
//   const HeaderWidget({super.key, required this.suraNumber});

//   @override
//   Widget build(BuildContext context) {
//     final surahName = getSurahName(suraNumber);
//     final isMeccan = _isMeccanSurah(suraNumber);
    
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 16),
//       child: Card(
//         elevation: 2,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Container(
//           width: double.infinity,
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
//               // Surah number in decorative style
//               Container(
//                 width: 60,
//                 height: 60,
//                 decoration: BoxDecoration(
//                   color: Colors.green[700],
//                   shape: BoxShape.circle,
//                 ),
//                 child: Center(
//                   child: Text(
//                     suraNumber.toString(),
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               // Surah name in Arabic
//               Text(
//                 surahName,
//                 style: const TextStyle(
//                   fontSize: 28,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.green[900],
//                 ),
//                 textDirection: TextDirection.rtl,
//               ),
//               const SizedBox(height: 8),
//               // Revelation info
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.location_on,
//                     size: 16,
//                     color: Colors.green[700],
//                   ),
//                   const SizedBox(width: 4),
//                   Text(
//                     isMeccan ? 'Meccan' : 'Medinan',
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: Colors.green[700],
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   Icon(
//                     Icons.format_list_numbered,
//                     size: 16,
//                     color: Colors.green[700],
//                   ),
//                   const SizedBox(width: 4),
//                   Text(
//                     '${getVerseCount(suraNumber)} Verses',
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: Colors.green[700],
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               // Bismillah for all surahs except At-Tawbah
//               if (suraNumber != 9)
//                 Text(
//                   '﷽',
//                   style: TextStyle(
//                     fontSize: 24,
//                     color: Colors.green[800],
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   bool _isMeccanSurah(int surahNumber) {
//     // Meccan surahs are generally 1-5, 6-7 have mixed revelations
//     // This is a simplified check - you might want to use your actual data
//     return surahNumber != 2 && surahNumber != 3 && surahNumber != 4 && 
//            surahNumber != 5 && surahNumber != 8 && surahNumber != 9 &&
//            surahNumber != 33 && surahNumber != 47 && surahNumber != 48 &&
//            surahNumber != 49 && surahNumber != 57 && surahNumber != 58 &&
//            surahNumber != 59 && surahNumber != 60 && surahNumber != 61 &&
//            surahNumber != 62 && surahNumber != 63 && surahNumber != 64 &&
//            surahNumber != 65 && surahNumber != 66 && surahNumber != 76 &&
//            surahNumber != 98 && surahNumber != 99 && surahNumber != 110;
//   }
// }