import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

/// Little Builder (ages 3 to 4, Helper mode on) or Big Builder (5 to 7).
enum PlayStyle { little, big }

/// Grown-ups settings (PAR-04, PAR-07, ONB-01).
@freezed
abstract class Settings with _$Settings {
  const factory Settings({
    @Default(PlayStyle.big) PlayStyle playStyle,
    @Default(true) bool music,
    @Default(true) bool sfx,
    @Default(true) bool voice,
    @Default(true) bool haptics,

    /// 0 means no limit; otherwise 15, 30 or 45 (PAR-07).
    @Default(0) int dailyLimitMinutes,
    @Default(false) bool onboardingDone,
  }) = _Settings;

  const Settings._();

  factory Settings.fromJson(Map<String, dynamic> json) =>
      _$SettingsFromJson(json);

  bool get helperMode => playStyle == PlayStyle.little;
}
