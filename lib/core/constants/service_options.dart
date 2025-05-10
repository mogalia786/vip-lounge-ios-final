class ServiceCategory {
  final String name;
  final List<Service> services;

  const ServiceCategory({
    required this.name,
    required this.services,
  });
}

class Service {
  final String id;
  final String name;
  final String description;
  final int minDuration;
  final int maxDuration;
  final List<SubService> subServices;

  const Service({
    required this.id,
    required this.name,
    required this.description,
    required this.minDuration,
    required this.maxDuration,
    this.subServices = const [],
  });
}

class SubService {
  final String name;
  final int minDuration;
  final int maxDuration;

  const SubService({
    required this.name,
    required this.minDuration,
    required this.maxDuration,
  });
}

class VenueType {
  final String id;
  final String name;
  final String description;
  final String location;
  final int cleaningBuffer;

  const VenueType({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.cleaningBuffer,
  });
}

// Venue definitions
final List<VenueType> venueTypes = [
  VenueType(
    id: 'executive_lounge',
    name: 'Executive Lounge',
    description: 'Luxurious lounge for private meetings',
    location: '1st Floor, East Wing',
    cleaningBuffer: 15,
  ),
  VenueType(
    id: 'vip_suite',
    name: 'VIP Suite',
    description: 'Private suite for exclusive meetings',
    location: '2nd Floor, East Wing',
    cleaningBuffer: 15,
  ),
  VenueType(
    id: 'conference_room',
    name: 'Conference Room',
    description: 'Spacious room for group discussions',
    location: '2nd Floor, West Wing',
    cleaningBuffer: 15,
  ),
];

// Service definitions
final List<ServiceCategory> serviceCategories = [
  ServiceCategory(
    name: 'Contract Services',
    services: [
      Service(
        id: 'new_contract',
        name: 'New Contract',
        description: 'Setup a new contract for services',
        minDuration: 30,
        maxDuration: 45,
      ),
      Service(
        id: 'contract_renewal',
        name: 'Renewal of Contract',
        description: 'Renew your existing contract',
        minDuration: 15,
        maxDuration: 30,
      ),
      Service(
        id: 'contract_migrations',
        name: 'Migrations (Change of Tariff Package)',
        description: 'Migrate your existing contract to a new plan',
        minDuration: 15,
        maxDuration: 30,
      ),
      Service(
        id: 'transfer_of_ownership',
        name: 'Transfer of Ownership',
        description: 'Transfer ownership of your account to a new owner',
        minDuration: 45,
        maxDuration: 45,
      ),
    ],
  ),
  ServiceCategory(
    name: 'Connectivity',
    services: [
      Service(
        id: 'connectivity_solutions',
        name: 'Connectivity Solutions',
        description: 'Get connected with our range of internet plans',
        minDuration: 30,
        maxDuration: 30,
      ),
    ],
  ),
  ServiceCategory(
    name: 'Business Solutions',
    services: [
      Service(
        id: 'business_solutions_consultation',
        name: 'Business Solutions Consultation',
        description: 'Expert advice on business solutions and growth strategies',
        minDuration: 45,
        maxDuration: 45,
      ),
    ],
  ),
  ServiceCategory(
    name: 'Device & SIM Services',
    services: [
      Service(
        id: 'prepaid_device_purchase',
        name: 'Prepaid Device Purchase',
        description: 'Buy a new prepaid device from our range of options',
        minDuration: 20,
        maxDuration: 30,
      ),
      Service(
        id: 'prepaid_sim_card_purchase',
        name: 'Prepaid SIM Card Purchase',
        description: 'Buy a new prepaid SIM card and get connected',
        minDuration: 15,
        maxDuration: 15,
      ),
      Service(
        id: 'prepaid_number_porting',
        name: 'Prepaid Number Porting',
        description: 'Port your existing number to our prepaid plans',
        minDuration: 15,
        maxDuration: 15,
      ),
      Service(
        id: 'postpaid_sim_swop',
        name: 'Postpaid SIM Swop',
        description: 'Swop your existing postpaid SIM card for a new one',
        minDuration: 15,
        maxDuration: 15,
      ),
      Service(
        id: 'prepaid_sim_swop',
        name: 'Prepaid SIM Swop',
        description: 'Swop your existing prepaid SIM card for a new one',
        minDuration: 15,
        maxDuration: 15,
      ),
    ],
  ),
  ServiceCategory(
    name: 'Accessories',
    services: [
      Service(
        id: 'accessories_purchase_and_setup',
        name: 'Accessories Purchase & Setup',
        description: 'Buy and set up accessories for your device',
        minDuration: 15,
        maxDuration: 45,
      ),
    ],
  ),
  ServiceCategory(
    name: 'Technical Support',
    services: [
      Service(
        id: 'technical_support_services',
        name: 'Technical Support Services',
        description: 'Get expert technical support for your device and services',
        minDuration: 30,
        maxDuration: 30,
        subServices: [
          SubService(
            name: 'Data Backup & Transfer',
            minDuration: 30,
            maxDuration: 30,
          ),
          SubService(
            name: 'Device Setup/Troubleshooting',
            minDuration: 30,
            maxDuration: 30,
          ),
          SubService(
            name: 'Email & Social Media Setup',
            minDuration: 30,
            maxDuration: 45,
          ),
          SubService(
            name: 'Laptop Setup & Configuration',
            minDuration: 45,
            maxDuration: 90,
          ),
          SubService(
            name: 'App Setup & Configuration',
            minDuration: 15,
            maxDuration: 30,
          ),
          SubService(
            name: 'Software Updates & Solutions',
            minDuration: 30,
            maxDuration: 60,
          ),
          SubService(
            name: 'Device Diagnostics',
            minDuration: 30,
            maxDuration: 45,
          ),
          SubService(
            name: 'Device Customization',
            minDuration: 30,
            maxDuration: 45,
          ),
          SubService(
            name: 'Training (School Me)',
            minDuration: 30,
            maxDuration: 60,
          ),
        ],
      ),
    ],
  ),
  ServiceCategory(
    name: 'Value Added Services',
    services: [
      Service(
        id: 'international_roaming',
        name: 'International Roaming',
        description: 'Set up international roaming on your account',
        minDuration: 15,
        maxDuration: 15,
      ),
      Service(
        id: 'blacklisting',
        name: 'Blacklisting',
        description: 'Blacklist a device on your account',
        minDuration: 15,
        maxDuration: 15,
      ),
      Service(
        id: 'itemised_billing',
        name: 'Itemised Billing',
        description: 'Set up itemised billing on your account',
        minDuration: 15,
        maxDuration: 15,
      ),
      Service(
        id: 'insurance_services',
        name: 'Insurance Services',
        description: 'Get insurance for your device',
        minDuration: 30,
        maxDuration: 30,
        subServices: [
          SubService(
            name: 'New Insurance',
            minDuration: 30,
            maxDuration: 30,
          ),
          SubService(
            name: 'Claim Processing',
            minDuration: 30,
            maxDuration: 30,
          ),
        ],
      ),
    ],
  ),
];
