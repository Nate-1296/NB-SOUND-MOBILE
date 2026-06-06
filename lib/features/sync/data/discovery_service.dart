import 'dart:async';

import 'package:nsd/nsd.dart';

/// Descubrimiento del PC ya emparejado por mDNS/DNS-SD (`_nbsound._tcp`), para
/// reconectar cuando cambia su IP en la red local (docs/pc-contract.md §1).
class DiscoveryService {
  static const String serviceType = '_nbsound._tcp';

  /// Busca el primer servicio NB Sound resuelto (host+puerto) o null al expirar.
  Future<Service?> findFirst({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final Discovery discovery = await startDiscovery(serviceType);
    final Completer<Service?> completer = Completer<Service?>();

    void listener(Service service, ServiceStatus status) {
      if (status == ServiceStatus.found &&
          service.host != null &&
          service.port != null &&
          !completer.isCompleted) {
        completer.complete(service);
      }
    }

    discovery.addServiceListener(listener);
    try {
      return await completer.future
          .timeout(timeout, onTimeout: () => null);
    } finally {
      discovery.removeServiceListener(listener);
      await stopDiscovery(discovery);
    }
  }
}
