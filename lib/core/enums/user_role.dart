enum UserRole {
  minister,
  floorManager,
  operationalManager,
  staff,
  consultant,
  concierge,
  cleaner,
  marketingAgent;
  
  /// Returns the display name for the client type
  static String getClientTypeDisplayName(String? clientType) {
    if (clientType == null || clientType.isEmpty) return 'Minister';
    
    // Convert snake_case to Title Case
    return clientType
        .split('_')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }
}
