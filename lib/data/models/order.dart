import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/core/utils/type_helper.dart';
import 'package:flutter_laundry_offline_app/data/models/order_item.dart';
import 'package:flutter_laundry_offline_app/data/models/payment.dart';

enum OrderStatus { pending, process, ready, done }

extension OrderStatusExtension on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.process:
        return 'process';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.done:
        return 'done';
    }
  }

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.process:
        return 'Proses';
      case OrderStatus.ready:
        return 'Siap Ambil';
      case OrderStatus.done:
        return 'Selesai';
    }
  }

  String get description {
    switch (this) {
      case OrderStatus.pending:
        return 'Order baru masuk';
      case OrderStatus.process:
        return 'Sedang dikerjakan';
      case OrderStatus.ready:
        return 'Selesai, siap diambil';
      case OrderStatus.done:
        return 'Sudah diambil';
    }
  }

  static OrderStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'process':
        return OrderStatus.process;
      case 'ready':
        return OrderStatus.ready;
      case 'done':
        return OrderStatus.done;
      default:
        return OrderStatus.pending;
    }
  }
}

class Order extends Equatable {
  final int? id;
  final String? remoteId; // Supabase UUID
  final String? outletId; // Supabase outlet UUID
  final String invoiceNo;
  final int? customerId; // Local customer ID
  final String? customerRemoteId; // Supabase customer UUID
  final String customerName;
  final String? customerPhone;
  final DateTime orderDate;
  final DateTime? dueDate;
  final OrderStatus status;
  final int totalItems;
  final double totalWeight;
  final int totalPrice;
  final int paid;
  final String? notes;
  final int? createdBy; // Local user ID
  final String? createdByRemoteId; // Supabase user UUID
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Relations (loaded separately)
  final List<OrderItem>? items;
  final List<Payment>? payments;

  const Order({
    this.id,
    this.remoteId,
    this.outletId,
    required this.invoiceNo,
    this.customerId,
    this.customerRemoteId,
    required this.customerName,
    this.customerPhone,
    required this.orderDate,
    this.dueDate,
    this.status = OrderStatus.pending,
    this.totalItems = 0,
    this.totalWeight = 0,
    required this.totalPrice,
    this.paid = 0,
    this.notes,
    this.createdBy,
    this.createdByRemoteId,
    this.createdAt,
    this.updatedAt,
    this.items,
    this.payments,
  });

  /// Check if this is a remote (Supabase) order
  bool get isRemote => remoteId != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'outlet_id': outletId,
      'invoice_no': invoiceNo,
      'customer_id': customerId,
      'customer_remote_id': customerRemoteId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'order_date': orderDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'status': status.value,
      'total_items': totalItems,
      'total_weight': totalWeight,
      'total_price': totalPrice,
      'paid': paid,
      'notes': notes,
      'created_by': createdBy,
      'created_by_remote_id': createdByRemoteId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Convert to Supabase-compatible map (excludes local id)
  Map<String, dynamic> toSupabaseMap() {
    return {
      if (remoteId != null) 'id': remoteId,
      'outlet_id': outletId,
      'invoice_no': invoiceNo,
      'customer_id': customerRemoteId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'order_date': orderDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'status': status.value,
      'total_items': totalItems,
      'total_weight': totalWeight,
      'total_price': totalPrice,
      'paid': paid,
      'notes': notes,
      'created_by': createdByRemoteId,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: TypeHelper.asNullableInt(map['id']),
      remoteId: TypeHelper.asNullableString(map['remote_id']),
      outletId: TypeHelper.asNullableString(map['outlet_id']),
      invoiceNo: map['invoice_no'] as String,
      customerId: TypeHelper.asNullableInt(map['customer_id']),
      customerRemoteId: TypeHelper.asNullableString(map['customer_remote_id']),
      customerName: map['customer_name'] as String,
      customerPhone: TypeHelper.asNullableString(map['customer_phone']),
      orderDate: DateTime.parse(map['order_date'] as String),
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      status: OrderStatusExtension.fromString(map['status'] as String),
      totalItems: TypeHelper.asInt(map['total_items']),
      totalWeight: TypeHelper.asDouble(map['total_weight']),
      totalPrice: TypeHelper.asInt(map['total_price']),
      paid: TypeHelper.asInt(map['paid']),
      notes: TypeHelper.asNullableString(map['notes']),
      createdBy: TypeHelper.asNullableInt(map['created_by']),
      createdByRemoteId: TypeHelper.asNullableString(map['created_by_remote_id']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Create from Supabase response
  factory Order.fromSupabase(Map<String, dynamic> map) {
    return Order(
      remoteId: TypeHelper.asNullableString(map['id']),
      outletId: TypeHelper.asNullableString(map['outlet_id']),
      invoiceNo: map['invoice_no'] as String,
      customerRemoteId: TypeHelper.asNullableString(map['customer_id']),
      customerName: map['customer_name'] as String,
      customerPhone: TypeHelper.asNullableString(map['customer_phone']),
      orderDate: DateTime.parse(map['order_date'] as String),
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      status: OrderStatusExtension.fromString(map['status'] as String),
      totalItems: TypeHelper.asInt(map['total_items']),
      totalWeight: TypeHelper.asDouble(map['total_weight']),
      totalPrice: TypeHelper.asInt(map['total_price']),
      paid: TypeHelper.asInt(map['paid']),
      notes: TypeHelper.asNullableString(map['notes']),
      createdByRemoteId: TypeHelper.asNullableString(map['created_by']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Order copyWith({
    int? id,
    String? remoteId,
    String? outletId,
    String? invoiceNo,
    int? customerId,
    String? customerRemoteId,
    String? customerName,
    String? customerPhone,
    DateTime? orderDate,
    DateTime? dueDate,
    OrderStatus? status,
    int? totalItems,
    double? totalWeight,
    int? totalPrice,
    int? paid,
    String? notes,
    int? createdBy,
    String? createdByRemoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OrderItem>? items,
    List<Payment>? payments,
  }) {
    return Order(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      outletId: outletId ?? this.outletId,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      customerId: customerId ?? this.customerId,
      customerRemoteId: customerRemoteId ?? this.customerRemoteId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      orderDate: orderDate ?? this.orderDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      totalItems: totalItems ?? this.totalItems,
      totalWeight: totalWeight ?? this.totalWeight,
      totalPrice: totalPrice ?? this.totalPrice,
      paid: paid ?? this.paid,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdByRemoteId: createdByRemoteId ?? this.createdByRemoteId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
      payments: payments ?? this.payments,
    );
  }

  // Helper methods
  int get remainingPayment => totalPrice - paid;
  bool get isPaid => paid >= totalPrice;
  bool get hasDeposit => paid > 0 && paid < totalPrice;

  // Aliases for printer service
  String get invoiceNumber => invoiceNo;
  int get subtotal => totalPrice;
  int get discount => 0; // No discount feature yet
  int get totalAmount => totalPrice;
  int get paidAmount => paid;

  bool get isOverdue {
    if (dueDate == null) return false;
    if (status == OrderStatus.done) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  // Get available next status transitions (flexible workflow)
  List<OrderStatus> getNextStatusOptions() {
    switch (status) {
      case OrderStatus.pending:
        return [OrderStatus.process];
      case OrderStatus.process:
        // Flexible: bisa langsung Done atau lewat Ready dulu
        return [OrderStatus.ready, OrderStatus.done];
      case OrderStatus.ready:
        return [OrderStatus.done];
      case OrderStatus.done:
        return []; // Final state
    }
  }

  String get whatsappNumber {
    if (customerPhone == null || customerPhone!.isEmpty) return '';
    String cleaned = customerPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    }
    return cleaned;
  }

  @override
  List<Object?> get props => [
        id,
        remoteId,
        outletId,
        invoiceNo,
        customerId,
        customerRemoteId,
        customerName,
        customerPhone,
        orderDate,
        dueDate,
        status,
        totalItems,
        totalWeight,
        totalPrice,
        paid,
        notes,
        createdBy,
        createdByRemoteId,
        createdAt,
        updatedAt,
      ];
}
