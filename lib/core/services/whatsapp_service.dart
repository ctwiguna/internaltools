import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_laundry_offline_app/data/models/order.dart';
import 'package:flutter_laundry_offline_app/data/repositories/settings_repository.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/core/utils/currency_formatter.dart';
import 'package:flutter_laundry_offline_app/core/utils/date_formatter.dart';
import 'package:flutter_laundry_offline_app/core/constants/app_constants.dart';

class WhatsAppService {
  static final WhatsAppService _instance = WhatsAppService._internal();
  factory WhatsAppService() => _instance;
  WhatsAppService._internal();

  final SettingsRepository _settingsRepository = SettingsRepository();

  /// Info laundry untuk pesan WA.
  /// Jika online & ada outlet aktif: nama brand + nama outlet + alamat,
  /// telepon, dan social media diambil dari data OUTLET di Supabase
  /// (fallback ke pengaturan global bila kolom outlet kosong / offline).
  Future<Map<String, String>> _getLaundryInfo() async {
    final settings = await _settingsRepository.getAllSettings();
    var name = settings[AppConstants.keyLaundryName] ??
        AppConstants.defaultLaundryName;
    var address = settings[AppConstants.keyLaundryAddress] ??
        AppConstants.defaultLaundryAddress;
    var phone = settings[AppConstants.keyLaundryPhone] ??
        AppConstants.defaultLaundryPhone;
    String outletName = '';
    String outletDisplayName = '';
    String socialMedia = '';

    try {
      final uuid = OutletService.instance.currentOutletUuid;
      if (uuid != null) {
        final row = await SupabaseService.instance.client
            .from('outlets')
            .select('name, display_name, address, phone, social_media')
            .eq('id', uuid)
            .maybeSingle();
        if (row != null) {
          outletName = (row['name'] as String?) ?? '';
          outletDisplayName = (row['display_name'] as String?) ?? '';
          socialMedia = (row['social_media'] as String?) ?? '';
          final outletAddress = row['address'] as String?;
          if (outletAddress != null && outletAddress.isNotEmpty) {
            address = outletAddress;
          }
          final outletPhone = row['phone'] as String?;
          if (outletPhone != null && outletPhone.isNotEmpty) {
            phone = outletPhone;
          }
        }
      }
    } catch (_) {
      // Offline / gagal fetch -> pakai pengaturan global saja
    }

    // Nama tercetak: display_name outlet (nama laundry per outlet),
    // fallback "Brand - Outlet", lalu brand global.
    final displayName = outletDisplayName.isNotEmpty
        ? outletDisplayName
        : (outletName.isNotEmpty ? '$name - $outletName' : name);

    return {
      'name': displayName,
      'outlet': outletName,
      'address': address,
      'phone': phone,
      'social_media': socialMedia,
    };
  }

  /// Send order receipt via WhatsApp
  Future<bool> shareOrderReceipt(Order order) async {
    if (order.customerPhone == null || order.customerPhone!.isEmpty) {
      throw Exception('Nomor HP pelanggan tidak tersedia');
    }

    final laundryInfo = await _getLaundryInfo();
    final receiverName = await _getReceiverName(order);
    final message = _buildReceiptMessage(order, laundryInfo, receiverName);
    final phoneNumber = order.whatsappNumber;

    if (phoneNumber.isEmpty) {
      throw Exception('Format nomor HP tidak valid');
    }

    final url = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      } else {
        throw Exception('Tidak dapat membuka WhatsApp');
      }
    } catch (e) {
      throw Exception('Gagal membuka WhatsApp: ${e.toString()}');
    }
  }

  /// Send order notification to customer
  Future<bool> sendOrderNotification(Order order, String notificationType) async {
    if (order.customerPhone == null || order.customerPhone!.isEmpty) {
      throw Exception('Nomor HP pelanggan tidak tersedia');
    }

    final laundryInfo = await _getLaundryInfo();
    final message = _buildNotificationMessage(order, notificationType, laundryInfo);
    final phoneNumber = order.whatsappNumber;

    if (phoneNumber.isEmpty) {
      throw Exception('Format nomor HP tidak valid');
    }

    final url = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      } else {
        throw Exception('Tidak dapat membuka WhatsApp');
      }
    } catch (e) {
      throw Exception('Gagal membuka WhatsApp: ${e.toString()}');
    }
  }

  /// Nama karyawan penerima order: dari profil pembuat order
  /// (created_by), fallback ke akun yang sedang login.
  Future<String> _getReceiverName(Order order) async {
    try {
      final client = SupabaseService.instance.client;
      final creatorId =
          order.createdByRemoteId ?? client.auth.currentUser?.id;
      if (creatorId == null) return '';
      final row = await client
          .from('profiles')
          .select('name')
          .eq('id', creatorId)
          .maybeSingle();
      return (row?['name'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  String _buildReceiptMessage(Order order, Map<String, String> laundryInfo, String receiverName) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('*${laundryInfo['name']}*');
    buffer.writeln(laundryInfo['address']);
    buffer.writeln('Telp: ${laundryInfo['phone']}');
    if ((laundryInfo['social_media'] ?? '').isNotEmpty) {
      buffer.writeln(laundryInfo['social_media']);
    }
    buffer.writeln('================================');
    buffer.writeln();

    // Invoice info
    buffer.writeln('*STRUK ORDER*');
    buffer.writeln('No: ${order.invoiceNumber}');
    buffer.writeln('Tgl: ${DateFormatter.formatDateTime(order.createdAt ?? DateTime.now())}');
    buffer.writeln('Pelanggan: ${order.customerName}');
    if (receiverName.isNotEmpty) {
      buffer.writeln('Penerima order: $receiverName');
    }
    buffer.writeln('Status: ${order.status.displayName}');
    buffer.writeln();

    // Items
    buffer.writeln('*Detail Layanan:*');
    buffer.writeln('--------------------------------');
    for (final item in order.items ?? []) {
      buffer.writeln('• ${item.serviceName}');
      buffer.writeln('  ${item.quantity} ${item.unit} x ${CurrencyFormatter.format(item.pricePerUnit)}');
      buffer.writeln('  = ${CurrencyFormatter.format(item.subtotal)}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln();

    // Total
    buffer.writeln('*TOTAL: ${CurrencyFormatter.format(order.totalAmount)}*');

    // Payment info
    if (order.paidAmount > 0) {
      buffer.writeln('Dibayar: ${CurrencyFormatter.format(order.paidAmount)}');
      final remaining = order.remainingPayment;
      if (remaining > 0) {
        buffer.writeln('*Sisa: ${CurrencyFormatter.format(remaining)}*');
      } else {
        buffer.writeln('✅ LUNAS');
      }
    } else {
      buffer.writeln('Belum ada pembayaran');
    }

    buffer.writeln();

    // Due date
    if (order.dueDate != null) {
      buffer.writeln('📅 Ambil: ${DateFormatter.formatDate(order.dueDate!)}');
    }

    // Notes
    if (order.notes != null && order.notes!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Catatan: ${order.notes}');
    }

    buffer.writeln();
    buffer.writeln('================================');
    buffer.writeln('Terima kasih atas kepercayaan Anda!');

    return buffer.toString();
  }

  String _buildNotificationMessage(Order order, String notificationType, Map<String, String> laundryInfo) {
    final buffer = StringBuffer();

    buffer.writeln('Halo ${order.customerName},');
    buffer.writeln();

    switch (notificationType) {
      case 'ready':
        buffer.writeln('🎉 *Laundry Anda sudah siap diambil!*');
        buffer.writeln();
        buffer.writeln('No. Order: ${order.invoiceNumber}');
        buffer.writeln();
        buffer.writeln('Silakan ambil laundry Anda di:');
        buffer.writeln('📍 ${laundryInfo['address']}');
        if (order.remainingPayment > 0) {
          buffer.writeln();
          buffer.writeln('*Sisa pembayaran: ${CurrencyFormatter.format(order.remainingPayment)}*');
        }
        break;

      case 'process':
        buffer.writeln('⏳ *Laundry Anda sedang diproses*');
        buffer.writeln();
        buffer.writeln('No. Order: ${order.invoiceNumber}');
        if (order.dueDate != null) {
          buffer.writeln('Estimasi selesai: ${DateFormatter.formatDate(order.dueDate!)}');
        }
        break;

      case 'done':
        buffer.writeln('✅ *Terima kasih!*');
        buffer.writeln();
        buffer.writeln('Order ${order.invoiceNumber} telah selesai.');
        buffer.writeln('Terima kasih telah menggunakan jasa kami.');
        buffer.writeln();
        buffer.writeln('Sampai jumpa di kunjungan berikutnya! 🙏');
        break;

      default:
        buffer.writeln('No. Order: ${order.invoiceNumber}');
        buffer.writeln('Status: ${order.status.displayName}');
    }

    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('${laundryInfo['name']}');
    buffer.writeln('Telp: ${laundryInfo['phone']}');
    if ((laundryInfo['social_media'] ?? '').isNotEmpty) {
      buffer.writeln(laundryInfo['social_media']);
    }

    return buffer.toString();
  }
}
