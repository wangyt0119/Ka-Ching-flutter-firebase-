// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'transaction_details.dart';

// class ActivityScreen extends StatefulWidget {
//   const ActivityScreen({super.key});

//   @override
//   State<ActivityScreen> createState() => _ActivityScreenState();
// }

// class _ActivityScreenState extends State<ActivityScreen> {
//   TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';

//   bool _sortAsc = false; // Default is descending

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   List<QueryDocumentSnapshot> _filterActivities(
//     List<QueryDocumentSnapshot> docs,
//   ) {
//     if (_searchQuery.isEmpty) return docs;
//     return docs.where((doc) {
//       final data = doc.data() as Map<String, dynamic>;
//       final name = data['name']?.toString().toLowerCase() ?? '';
//       final createdBy = data['createdByName']?.toString().toLowerCase() ?? '';
//       return name.contains(_searchQuery) || createdBy.contains(_searchQuery);
//     }).toList();
//   }

//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final isMobile = screenWidth < 768;

//     return Padding(
//       padding: EdgeInsets.all(isMobile ? 16 : 24),
//       child: Column(
//         children: [
//           // Header with search and sort
//           Row(
//             children: [
//               Expanded(
//                 child: TextField(
//                   controller: _searchController,
//                   onChanged: (value) {
//                     setState(() {
//                       _searchQuery = value.trim().toLowerCase();
//                     });
//                   },
//                   decoration: InputDecoration(
//                     hintText: 'Search activities...',
//                     prefixIcon: const Icon(Icons.search),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                 ),
//               ),
//               if (!isMobile) ...[
//                 const SizedBox(width: 16),
//                 ElevatedButton.icon(
//                   onPressed: () {
//                     setState(() => _sortAsc = !_sortAsc);
//                   },
//                   icon: Icon(
//                     _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
//                   ),
//                   label: Text(_sortAsc ? 'Sort Asc' : 'Sort Desc'),
//                 ),
//               ],
//             ],
//           ),
//           if (isMobile) ...[
//             const SizedBox(height: 12),
//             SizedBox(
//               width: double.infinity,
//               child: OutlinedButton.icon(
//                 onPressed: () {
//                   setState(() => _sortAsc = !_sortAsc);
//                 },
//                 icon: Icon(
//                   _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
//                 ),
//                 label: Text(_sortAsc ? 'Sort Asc' : 'Sort Desc'),
//               ),
//             ),
//           ],
//           const SizedBox(height: 24),

//           // Activities List
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream:
//                   FirebaseFirestore.instance
//                       .collectionGroup('activities')
//                       .orderBy('createdAt', descending: !_sortAsc)
//                       .limit(50)
//                       .snapshots(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 }

//                 if (snapshot.hasError) {
//                   return Center(
//                     child: Text(
//                       'Error loading activities: ${snapshot.error}',
//                       style: const TextStyle(color: Colors.red),
//                     ),
//                   );
//                 }

//                 if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                   return const Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.local_activity_outlined,
//                           size: 64,
//                           color: Colors.grey,
//                         ),
//                         SizedBox(height: 16),
//                         Text(
//                           'No activities found',
//                           style: TextStyle(fontSize: 18, color: Colors.grey),
//                         ),
//                       ],
//                     ),
//                   );
//                 }

//                 final filteredDocs = _filterActivities(snapshot.data!.docs);

//                 return ListView.builder(
//                   itemCount: filteredDocs.length,
//                   itemBuilder: (context, index) {
//                     final doc = filteredDocs[index];
//                     final data = doc.data() as Map<String, dynamic>;
//                     final title =
//                         data['name']?.toString() ?? 'Untitled Activity';
//                     final description =
//                         data['description']?.toString() ?? 'No description';
//                     final createdAt = data['createdAt'] as Timestamp?;
//                     final members = data['members'] as List<dynamic>? ?? [];

//                     return Card(
//                       margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
//                       child: ListTile(
//                         leading: CircleAvatar(
//                           backgroundColor: Colors.green,
//                           child: Text(
//                             title.isNotEmpty ? title[0].toUpperCase() : 'A',
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         title: Text(
//                           title,
//                           style: const TextStyle(fontWeight: FontWeight.w600),
//                         ),
//                         subtitle: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               description,
//                               maxLines: isMobile ? 1 : 2,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                             const SizedBox(height: 4),
//                             Row(
//                               children: [
//                                 Icon(
//                                   Icons.person,
//                                   size: 14,
//                                   color: Colors.grey[600],
//                                 ),
//                                 const SizedBox(width: 4),
//                                 Text(
//                                   'Created by: ${data['createdByName'] ?? 'Unknown'}',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: Colors.grey[600],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 4),
//                             Row(
//                               children: [
//                                 Icon(
//                                   Icons.people,
//                                   size: 14,
//                                   color: Colors.grey[600],
//                                 ),
//                                 const SizedBox(width: 4),
//                                 Text(
//                                   '${members.length} members',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: Colors.grey[600],
//                                   ),
//                                 ),
//                                 if (createdAt != null) ...[
//                                   const SizedBox(width: 16),
//                                   Icon(
//                                     Icons.access_time,
//                                     size: 14,
//                                     color: Colors.grey[600],
//                                   ),
//                                   const SizedBox(width: 4),
//                                   Text(
//                                     _formatDate(createdAt.toDate()),
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.grey[600],
//                                     ),
//                                   ),
//                                 ],
//                               ],
//                             ),
//                           ],
//                         ),
//                         trailing: const Icon(Icons.chevron_right),
//                         onTap: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder:
//                                   (context) => TransactionDetailsScreen(
//                                     activity_id: doc.id,
//                                     activityData:
//                                         doc.data() as Map<String, dynamic>,
//                                     ownerUid:
//                                         (doc.data()
//                                             as Map<
//                                               String,
//                                               dynamic
//                                             >)['createdBy'],
//                                   ),
//                             ),
//                           );
//                         },
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _formatDate(DateTime date) {
//     return '${date.day}/${date.month}/${date.year}';
//   }
// }
