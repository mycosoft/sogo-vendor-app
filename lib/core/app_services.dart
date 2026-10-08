import 'api/api_client.dart';
import 'api/auth_api.dart';
import 'api/payment_api.dart';
import 'api/provider_api.dart';
import 'api/service_api.dart';
import 'api/notification_api.dart';
import 'api/messages_api.dart';
import 'api/locations_api.dart';

const String kApiBaseUrl = String.fromEnvironment(
  'SOGO_API_BASE_URL',
  defaultValue: 'https://sogo.co.ug',
);

final ApiClient apiClient = ApiClient(baseUrl: kApiBaseUrl);
final AuthApi authApi = AuthApi(apiClient);
final ProviderApi providerApi = ProviderApi(apiClient);
final PaymentApi paymentApi = PaymentApi(apiClient);
final ServiceApi serviceApi = ServiceApi(apiClient);
final NotificationApi notificationApi = NotificationApi(apiClient);
final MessagesApi messagesApi = MessagesApi(apiClient);
final LocationsApi locationsApi = LocationsApi(apiClient);
