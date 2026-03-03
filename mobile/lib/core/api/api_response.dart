class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final Map<String, dynamic>? pagination;
  final Map<String, List<String>>? errors;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.pagination,
    this.errors,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      pagination: json['pagination'] != null
          ? Map<String, dynamic>.from(json['pagination'])
          : null,
      errors: json['errors'] != null
          ? (json['errors'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, List<String>.from(v)),
            )
          : null,
    );
  }
}
