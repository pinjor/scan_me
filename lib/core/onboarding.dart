import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kOnboardingDoneKey = 'onboarding_done_v1';

enum OnboardingGate { loading, show, ready }

final onboardingProvider =
    StateNotifierProvider<OnboardingController, OnboardingGate>(
      (ref) => OnboardingController(),
    );

class OnboardingController extends StateNotifier<OnboardingGate> {
  OnboardingController() : super(OnboardingGate.loading) {
    _load();
  }

  /// Tests — skip prefs.
  OnboardingController.completed() : super(OnboardingGate.ready);

  OnboardingController.needed() : super(OnboardingGate.show);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(kOnboardingDoneKey) ?? false;
    state = done ? OnboardingGate.ready : OnboardingGate.show;
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingDoneKey, true);
    state = OnboardingGate.ready;
  }
}
