import 'package:freezed_annotation/freezed_annotation.dart';

part 'decal.freezed.dart';
part 'decal.g.dart';

/// A robot decal (WRK-10). A cost of 0 means it is free from the start.
@freezed
abstract class Decal with _$Decal {
  const factory Decal({
    required String id,
    required String spriteAsset,
    @Default(0) int cost,
  }) = _Decal;

  factory Decal.fromJson(Map<String, dynamic> json) => _$DecalFromJson(json);
}
