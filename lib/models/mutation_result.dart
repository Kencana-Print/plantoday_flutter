class MutationResult {
  final bool success;
  final String message;
  final String? nomor;

  const MutationResult({
    required this.success,
    required this.message,
    this.nomor,
  });

  factory MutationResult.success({
    String message = 'Berhasil memperbarui data',
    String? nomor,
  }) {
    return MutationResult(
      success: true,
      message: message,
      nomor: nomor,
    );
  }

  factory MutationResult.failure({
    String message = 'Gagal memperbarui data',
    String? nomor,
  }) {
    return MutationResult(
      success: false,
      message: message,
      nomor: nomor,
    );
  }
}
