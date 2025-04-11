import 'dart:math';
import 'package:fft_nullsafety/fft.dart';
import 'package:complex/complex.dart'; // Add this import

class AudioProcessor {
  /// Compare two audio samples using spectrum analysis
  static double comparePronunciations(
    List<double> userAudio,
    List<double> referenceAudio,
  ) {
    final fft = FFT();

    // Get frequency spectra
    final userSpectrum = _getNormalizedSpectrum(fft, userAudio);
    final referenceSpectrum = _getNormalizedSpectrum(fft, referenceAudio);

    // Calculate cosine similarity
    return cosineSimilarity(userSpectrum, referenceSpectrum);
  }

  static List<double> _getNormalizedSpectrum(FFT fft, List<double> samples) {
    // Apply Hann window
    final windowed = _applyHannWindow(samples);

    // Perform FFT
    final spectrum = fft.Transform(windowed);

    // Get magnitude spectrum (first half)
     final magnitudes = spectrum
        .sublist(0, spectrum.length ~/ 2)
        .map<double>((c) => Complex(c.real.toDouble(), c.imaginary.toDouble()).abs())
        .toList();

    // Normalize
    final maxVal = magnitudes.reduce((double a, double b) => max(a, b));
    if (maxVal == 0) return List.filled(magnitudes.length, 0.0);
    return magnitudes.map<double>((double m) => m / maxVal).toList();
  }

  static List<double> _applyHannWindow(List<double> samples) {
    final windowed = List<double>.filled(samples.length, 0);
    for (var i = 0; i < samples.length; i++) {
      final multiplier = 0.5 * (1 - cos(2 * pi * i / (samples.length - 1)));
      windowed[i] = multiplier * samples[i];
    }
    return windowed;
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    
    double dot = 0, normA = 0, normB = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0) return 0.0;
    return dot / denominator;
  }
}