import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/familiares/presentation/providers/family_providers.dart';
import 'package:restaurante_app/features/pension/data/supabase_pension_repository.dart';

final pensionRepositoryProvider = Provider<SupabasePensionRepository>((ref) {
  return SupabasePensionRepository();
});

/// Proveedor del estado de pensión (Pensionado vs Regular) del empleado (clave `null`)
/// y de sus familiares (clave `id_familiar`) para una fecha / mes específico.
final comensalesPensionStatusProvider =
    FutureProvider.family<Map<String?, bool>, DateTime>((ref, date) async {
  final user = ref.watch(authProvider);
  if (user == null) {
    return {null: false};
  }

  final familyMembers = ref.watch(employeeFamilyMembersProvider).value ?? [];
  final familiarIds = familyMembers.map((f) => f.id).toList();

  final repo = ref.watch(pensionRepositoryProvider);
  return repo.getPensionStatusForComensales(
    userId: user.id,
    familiarIds: familiarIds,
    year: date.year,
    month: date.month,
  );
});
