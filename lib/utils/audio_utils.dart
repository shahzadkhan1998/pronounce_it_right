import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_sound_processing/flutter_sound_processing.dart';

class AudioUtils {
  /// Extracts MFCC features from audio samples.
  static Future<List<List<double>>> extractMFCC(
      List<double> samples, int sampleRate) async {
    final processor = FlutterSoundProcessing();

    // Parameters for MFCC extraction
    final frameSize = 1024; // FFT size
    final hopSize = 512; // Hop length
    final numFilters = 40; // Number of Mel filters
    final numCoefficients = 13; // Number of MFCC coefficients

    // Calculate the feature matrix
    final Float64List? featureMatrix = await processor.getFeatureMatrix(
      signals: samples,
      sampleRate: sampleRate,
      fftSize: frameSize,
      hopLength: hopSize,
      nMels: numFilters,
      mfcc: numCoefficients,
    );

    // Handle null case
    if (featureMatrix == null) {
      throw Exception('Failed to calculate MFCC features: featureMatrix is null');
    }

    // Convert Float64List to List<List<double>>
    final int numFrames = featureMatrix.length ~/ numCoefficients;
    final List<List<double>> mfccFeatures = List.generate(
      numFrames,
      (i) => featureMatrix
          .sublist(i * numCoefficients, (i + 1) * numCoefficients)
          .toList(),
    );

    return mfccFeatures;
  }

  /// Calculates similarity between two MFCC feature matrices using DTW.
  static double calculateSimilarityWithMFCC(
      List<List<double>> mfcc1, List<List<double>> mfcc2) {
    final n = mfcc1.length;
    final m = mfcc2.length;

    // Log the dimensions of the MFCC matrices
    print('MFCC1: $n frames, MFCC2: $m frames');
    if (n == 0 || m == 0) {
      throw Exception('MFCC matrices cannot be empty.');
    }

    // Normalize MFCC features
    mfcc1 = normalizeMFCC(mfcc1);
    mfcc2 = normalizeMFCC(mfcc2);

    // Log the first frame of each MFCC matrix for debugging
    print('MFCC1 (first frame): ${mfcc1[0]}');
    print('MFCC2 (first frame): ${mfcc2[0]}');

    // Initialize DTW matrix
    final dtw = List.generate(n, (_) => List.filled(m, double.infinity));
    dtw[0][0] = 0.0;

    // Compute DTW
    for (int i = 1; i < n; i++) {
      for (int j = 1; j < m; j++) {
        final cost = _euclideanDistance(mfcc1[i], mfcc2[j]);
        dtw[i][j] = cost +
            _min3(dtw[i - 1][j], dtw[i][j - 1], dtw[i - 1][j - 1]);

        // Log the cost and DTW value for debugging
        print('DTW[$i][$j]: cost=$cost, value=${dtw[i][j]}');
      }
    }

    // Log the final DTW distance
    final dtwDistance = dtw[n - 1][m - 1];
    print('Final DTW Distance: $dtwDistance');

    // Check for invalid DTW distance
    if (dtwDistance.isInfinite || dtwDistance.isNaN) {
      throw Exception('Invalid DTW distance: $dtwDistance');
    }

    // Normalize the DTW distance to a similarity score
    final maxDistance = max(n, m).toDouble();
    final maxPossibleDistance = n * m.toDouble(); // Maximum possible DTW distance
    final similarity = max(0.0, 1.0 - (dtwDistance / (maxPossibleDistance + 1e-6)));

    // Log the similarity score before returning
    print('DTW Distance: $dtwDistance');
    print('Max Distance (frames): $maxDistance');
    print('Max Possible Distance: $maxPossibleDistance');
    print('Similarity (after clamping): $similarity');

    return similarity;
  }

  static List<List<double>> normalizeMFCC(List<List<double>> mfcc) {
    final flattened = mfcc.expand((e) => e).toList();
    final minVal = flattened.reduce(min);
    final maxVal = flattened.reduce(max);
    return mfcc.map((frame) => frame.map((val) => (val - minVal) / (maxVal - minVal)).toList()).toList();
  }

  /// Parses WAV file bytes into normalized audio samples.
  static List<double> parseWavBytes(List<int> bytes) {
    const headerSize = 44; // Standard WAV header size
    final samples = <double>[];

    // Ensure the file has a valid header
    if (bytes.length <= headerSize) {
      throw Exception('Invalid WAV file: Too short to contain a header.');
    }

    // Convert bytes to 16-bit PCM samples
    for (var i = headerSize; i < bytes.length; i += 2) {
      if (i + 1 >= bytes.length) break;

      // Combine two bytes into a 16-bit sample
      final sample = bytes[i] | (bytes[i + 1] << 8);
      // Convert to signed value
      final signedSample = (sample & 0x8000) != 0 ? sample - 0x10000 : sample;
      // Normalize to range [-1.0, 1.0]
      samples.add(signedSample / 32768.0);
    }

    // Normalize the entire signal to have a maximum absolute value of 1.0
    final maxAmplitude = samples.map((e) => e.abs()).reduce(max);
    if (maxAmplitude > 0) {
      for (int i = 0; i < samples.length; i++) {
        samples[i] /= maxAmplitude;
      }
    }

    return samples;
  }

  /// Trims silence from the beginning and end of audio samples.
  static List<double> trimSilence(List<double> samples, double threshold) {
    int start = 0;
    int end = samples.length - 1;

    while (start < samples.length && samples[start].abs() < threshold) {
      start++;
    }
    while (end > start && samples[end].abs() < threshold) {
      end--;
    }

    return samples.sublist(start, end + 1);
  }

  /// Calculates the Euclidean distance between two vectors.
  static double _euclideanDistance(List<double> vec1, List<double> vec2) {
    if (vec1.length != vec2.length) {
      throw Exception('Vector lengths do not match: ${vec1.length} vs ${vec2.length}');
    }
    double sum = 0.0;
    for (int i = 0; i < vec1.length; i++) {
      sum += (vec1[i] - vec2[i]) * (vec1[i] - vec2[i]);
    }
    return sqrt(sum);
  }

  /// Returns the minimum of three values.
  static double _min3(double a, double b, double c) {
    return min(a, min(b, c));
  }
}

class FFT {
  /// Computes the FFT of the input signal.
  /// [input] is a list of complex numbers (real and imaginary parts).
  /// Returns a list of complex numbers representing the frequency domain.
  static List<Complex> computeFFT(List<Complex> input) {
    final n = input.length;

    // Ensure the input length is a power of 2
    if ((n & (n - 1)) != 0) {
      throw ArgumentError('Input length must be a power of 2');
    }

    // Base case: if the input length is 1, return the input
    if (n == 1) {
      return [input[0]];
    }

    // Split the input into even and odd indices
    final even = List<Complex>.generate(n ~/ 2, (i) => input[2 * i]);
    final odd = List<Complex>.generate(n ~/ 2, (i) => input[2 * i + 1]);

    // Recursively compute the FFT for even and odd parts
    final fftEven = computeFFT(even);
    final fftOdd = computeFFT(odd);

    // Combine the results
    final result = List<Complex>.filled(n, Complex(0, 0));
    for (int k = 0; k < n ~/ 2; k++) {
      final t = fftOdd[k] * Complex.polar(1, -2 * pi * k / n);
      result[k] = fftEven[k] + t;
      result[k + n ~/ 2] = fftEven[k] - t;
    }

    return result;
  }
}

class Complex {
  final double real;
  final double imaginary;

  Complex(this.real, this.imaginary);

  /// Adds two complex numbers.
  Complex operator +(Complex other) {
    return Complex(real + other.real, imaginary + other.imaginary);
  }

  /// Subtracts two complex numbers.
  Complex operator -(Complex other) {
    return Complex(real - other.real, imaginary - other.imaginary);
  }

  /// Multiplies two complex numbers.
  Complex operator *(Complex other) {
    return Complex(
      real * other.real - imaginary * other.imaginary,
      real * other.imaginary + imaginary * other.real,
    );
  }

  /// Computes the modulus (magnitude) of the complex number.
  double get modulus => sqrt(real * real + imaginary * imaginary);

  /// Creates a complex number in polar form.
  static Complex polar(double magnitude, double phase) {
    return Complex(magnitude * cos(phase), magnitude * sin(phase));
  }

  @override
  String toString() => '${real.toStringAsFixed(2)} + ${imaginary.toStringAsFixed(2)}i';
}

