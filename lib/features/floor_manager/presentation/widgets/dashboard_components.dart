import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';

class DashboardStats extends StatelessWidget {
  final int unassignedQueries;
  final int overdueQueries;
  final int pendingAppointments;
  final VoidCallback onShowOverdueQueries;
  final VoidCallback onShowUnassignedQueries;
  final VoidCallback onShowPendingAppointments;

  const DashboardStats({
    Key? key,
    required this.unassignedQueries,
    required this.overdueQueries,
    required this.pendingAppointments,
    required this.onShowOverdueQueries,
    required this.onShowUnassignedQueries,
    required this.onShowPendingAppointments,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard(
                title: 'Unassigned Queries',
                value: unassignedQueries.toString(),
                icon: Icons.question_answer_outlined,
                color: Colors.orange[400]!,
                onTap: onShowUnassignedQueries,
              ),
              _buildStatCard(
                title: 'Overdue Queries',
                value: overdueQueries.toString(),
                icon: Icons.warning_amber_rounded,
                color: Colors.red[400]!,
                isUrgent: overdueQueries > 0,
                onTap: onShowOverdueQueries,
              ),
              _buildStatCard(
                title: 'Pending Appointments',
                value: pendingAppointments.toString(),
                icon: Icons.event_available_outlined,
                color: AppColors.gold,
                onTap: onShowPendingAppointments,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isUrgent = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: color.withOpacity(0.2), width: 1.0),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.05),
              color.withOpacity(0.01),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18.0),
                ),
                const Spacer(),
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14.0, color: Colors.red[300]),
                        const SizedBox(width: 4.0),
                        const Text(
                          'Urgent',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16.0),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 28.0,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12.0,
                letterSpacing: 0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final bool autofocus;

  const SearchBarWidget({
    Key? key,
    required this.controller,
    required this.onSearch,
    this.autofocus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onSearch,
        autofocus: autofocus,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
        ),
      ),
    );
  }
}
