import 'package:freezed_annotation/freezed_annotation.dart';

part 'sticker.freezed.dart';
part 'sticker.g.dart';

/// A sticker book entry (STK-01). [rule] names the discovery that earns it;
/// sticker_rules interprets it in build step 15.
@freezed
abstract class Sticker with _$Sticker {
  const factory Sticker({
    required String id,
    required String iconAsset,
    required String clueKey,
    required String rule,
  }) = _Sticker;

  factory Sticker.fromJson(Map<String, dynamic> json) =>
      _$StickerFromJson(json);
}
