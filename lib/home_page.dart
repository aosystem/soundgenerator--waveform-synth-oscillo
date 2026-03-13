import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

import 'package:soundgenerator/parse_locale_tag.dart';
import 'package:soundgenerator/setting_page.dart';
import 'package:soundgenerator/theme_color.dart';
import 'package:soundgenerator/theme_mode_number.dart';
import 'package:soundgenerator/waveform_painter.dart';
import 'package:soundgenerator/ad_manager.dart';
import 'package:soundgenerator/loading_screen.dart';
import 'package:soundgenerator/model.dart';
import 'package:soundgenerator/main.dart';
import 'package:soundgenerator/ad_banner_widget.dart';

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});
  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage>with WidgetsBindingObserver {
  late AdManager _adManager;
  late ThemeColor _themeColor;
  bool _isReady = false;
  bool _isFirst = true;
  //
  final TextEditingController _freqController = TextEditingController();
  String _waveType = 'Sine';
  double _gain = 0.5;
  double _frequency = 440.0;
  double _lfoFreq = 0.0;
  double _lfoDepth = 0.0;
  double _panner = 0.0;
  bool _isPlaying = false;
  int _octave = 0;
  double _currentBaseFreq = 440.0;
  double _phase = 0.0;
  double _lfoPhase = 0.0;
  static const int _sampleRate = 44100;
  List<double> _leftSamples = [];
  List<double> _rightSamples = [];
  final Map<String, double> _notes = {
    'C': 261.63, 'C#': 277.18, 'D': 293.66, 'D#': 311.13,
    'E': 329.63, 'F': 349.23, 'F#': 369.99, 'G': 392.00,
    'G#': 415.30, 'A': 440.00, 'A#': 466.16, 'B': 493.88,
    'C5': 523.25,
  };
  double _envelope = 0.0;
  bool _isStopping = false;
  static const double _fadeDuration = 0.3;
  static const double _fadeStep = 1.0 / (_sampleRate * _fadeDuration);

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void _initState() async {
    _adManager = AdManager();
    _freqController.text = _frequency.toStringAsFixed(2);
    WidgetsBinding.instance.addObserver(this);
    _initAudio();
    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _freqController.dispose();
    FlutterPcmSound.release();
    _adManager.dispose();
    super.dispose();
  }

  void _initAudio() async {
    await FlutterPcmSound.setup(sampleRate: _sampleRate, channelCount: 2);
    await FlutterPcmSound.setFeedThreshold(_sampleRate ~/ 20);
    FlutterPcmSound.setFeedCallback(_onFeed);
  }

  void _onFeed(int remainingFrames) async {
    if (!_isPlaying && _envelope <= 0) {
      return;
    }

    const int framesToGenerate = 2048;
    final List<int> buffer = [];
    final List<double> currentL = [];
    final List<double> currentR = [];

    for (int i = 0; i < framesToGenerate; i++) {
      if (_isPlaying && !_isStopping) {
        _envelope = (_envelope + _fadeStep).clamp(0.0, 1.0);
      } else if (_isStopping) {
        _envelope = (_envelope - _fadeStep).clamp(0.0, 1.0);
        if (_envelope <= 0) {
          _isPlaying = false;
          _isStopping = false;
        }
      }

      _lfoPhase += 2 * pi * _lfoFreq / _sampleRate;
      double vibrato = sin(_lfoPhase) * _lfoDepth;
      double currentFreq = (_frequency + vibrato).clamp(20.0, 20000.0);
      _phase += 2 * pi * currentFreq / _sampleRate;
      _phase %= 2 * pi;

      double sample = _calcSample(_phase, _waveType);

      double leftVol = _gain * _envelope * (1.0 - _panner).clamp(0.0, 1.0);
      double rightVol = _gain * _envelope * (1.0 + _panner).clamp(0.0, 1.0);

      buffer.add((sample * leftVol * 32767).toInt());
      buffer.add((sample * rightVol * 32767).toInt());

      if (i < 256) {
        currentL.add(sample * leftVol);
        currentR.add(sample * rightVol);
      }
    }

    if (_isPlaying || _envelope > 0) {
      await FlutterPcmSound.feed(PcmArrayInt16.fromList(buffer));
    }

    setState(() {
      _leftSamples = currentL;
      _rightSamples = currentR;
    });
  }

  void _togglePlay() async {
    if (_isPlaying && !_isStopping) {
      setState(() => _isStopping = true);
    } else if (!_isPlaying) {
      setState(() {
        _isPlaying = true;
        _isStopping = false;
        _envelope = 0.0;
      });
      FlutterPcmSound.start();
    }
  }

  double _calcSample(double phase, String type) {
    switch (type) {
      case 'Sine': return sin(phase);
      case 'Square': return sin(phase) >= 0 ? 1.0 : -1.0;
      case 'Sawtooth': return 2.0 * (phase / (2 * pi) - (phase / (2 * pi)).floor()) - 1.0;
      case 'Triangle': return (2.0 * (phase / (2 * pi) - (phase / (2 * pi) + 0.5).floor())).abs() * 2.0 - 1.0;
      default: return 0.0;
    }
  }

  void _updateOctave(int delta) {
    setState(() {
      _octave += delta;
      _frequency = (_currentBaseFreq * pow(2, _octave)).clamp(20.0, 20000.0);
    });
  }

  void _playNote(double baseFreq) {
    setState(() {
      _currentBaseFreq = baseFreq;
      _frequency = (baseFreq * pow(2, _octave)).clamp(20.0, 20000.0);
    });
  }

  void _resetOctave() {
    setState(() {
      _octave = 0;
      _frequency = _currentBaseFreq;
    });
  }

  void _openSetting() async {
    final updatedSettings = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingPage(),
      ),
    );
    if (updatedSettings != null) {
      if (mounted) {
        final mainState = context.findAncestorStateOfType<MainAppState>();
        if (mainState != null) {
          mainState
            ..locale = parseLocaleTag(Model.languageCode)
            ..themeMode = ThemeModeNumber.numberToThemeMode(Model.themeNumber)
            ..setState(() {});
        }
      }
      if (mounted) {
        setState(() {
          _isFirst = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return LoadingScreen();
    }
    if (_isFirst) {
      _isFirst = false;
      _themeColor = ThemeColor(themeNumber: Model.themeNumber, context: context);
    }
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: _themeColor.mainBackColor,
      body: Stack(children:[
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_themeColor.mainBack2Color, _themeColor.mainBackColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            image: DecorationImage(
              image: AssetImage('assets/image/tile.png'),
              repeat: ImageRepeat.repeat,
              opacity: 0.1,
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Text('SOUND GENERATOR', style: t.titleSmall?.copyWith(color: _themeColor.mainForeColor)),
                    const Spacer(),
                    IconButton(
                      onPressed: _openSetting,
                      icon: Icon(Icons.settings,color: _themeColor.mainForeColor.withValues(alpha: 0.6)),
                    ),
                  ],
                )
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 1, bottom: 100),
                    child: Column(
                      children: [
                        _buildOscilloscope(),
                        _buildOctavePianoKeyboard(),
                        _buildSelector(),
                        _buildPlayButton(),
                      ]
                    )
                  )
                )
              )
            ]
          )
        )
      ]),
      bottomNavigationBar: AdBannerWidget(adManager: _adManager),
    );
  }

  Widget _buildOscilloscope() {
    return Container(
      height: 80,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _themeColor.mainCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: WaveformPainter(left: _leftSamples, right: _rightSamples),
      ),
    );
  }

  Widget _buildOctavePianoKeyboard() {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.only(left: 0, top: 8, right: 0, bottom: 0),
        color: _themeColor.cardColor,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOctave(),
              _buildPianoKeyboard()
            ],
          ),
        ),
      )
    );
  }

  Widget _buildOctave() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Octave: ", style: TextStyle(color: _themeColor.mainForeColor)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => _updateOctave(-1),
        ),
        Text("$_octave", style: TextStyle(color: _themeColor.mainForeColor, fontSize: 20, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => _updateOctave(1),
        ),
        TextButton(
          onPressed: _resetOctave,
          child: const Text("Reset"),
        )
      ],
    );
  }

  Widget _buildPianoKeyboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double whiteKeyWidth = totalWidth / 8;
        final double whiteKeyHeight = whiteKeyWidth * 1.3;
        final double blackKeyWidth = whiteKeyWidth * 0.8;
        final double blackKeyHeight = whiteKeyHeight * 0.5;
        final List<String> whiteNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B', 'C5'];
        final Map<int, String> blackNotes = {0: 'C#', 1: 'D#', 3: 'F#', 4: 'G#', 5: 'A#'};
        return SizedBox(
          height: whiteKeyHeight + 10,
          width: totalWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: whiteNotes.map((note) {
                  return SizedBox(
                    width: whiteKeyWidth,
                    height: whiteKeyHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 4,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(5)),
                        ),
                        side: const BorderSide(color: Colors.black26, width: 0.5),
                        padding: const EdgeInsets.only(bottom: 10),
                      ),
                      onPressed: () => _playNote(_notes[note]!),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Text(note, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              ...blackNotes.entries.map((entry) {
                int index = entry.key;
                String note = entry.value;
                double leftPosition = (index + 1) * whiteKeyWidth - (blackKeyWidth / 2);

                return Positioned(
                  left: leftPosition,
                  top: 0,
                  child: SizedBox(
                    width: blackKeyWidth,
                    height: blackKeyHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => _playNote(_notes[note]!),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(note, style: const TextStyle(fontSize: 8, color: Colors.white70)),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelector() {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.only(left: 0, top: 8, right: 0, bottom: 0),
        color: _themeColor.cardColor,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildWaveTypeSelector(),
                  ),
                  Expanded(
                    child: _buildTextFrequency(),
                  ),
                ],
              ),
              _buildSlider("Frequency (Hz)",
                _frequency.clamp(20.0, 20000.0), 20.0, 20000.0, (v) => setState(() {
                  _frequency = v;
                  _currentBaseFreq = v / pow(2, _octave);
                  _freqController.text = v.toStringAsFixed(2);
                }),
              ),
              _buildSlider("Gain", _gain, 0.0, 1.0, (v) => setState(() => _gain = v)),
              _buildSlider("LFO Freq", _lfoFreq, 0.0, 20.0, (v) => setState(() => _lfoFreq = v)),
              _buildSlider("LFO Depth", _lfoDepth, 0.0, 100.0, (v) => setState(() => _lfoDepth = v)),
              _buildSlider("Panner", _panner, -1.0, 1.0, (v) => setState(() => _panner = v)),
            ],
          ),
        ),
      )
    );
  }

  Widget _buildTextFrequency() {
    return SizedBox(
      height: 35,
      child: TextFormField(
        controller: _freqController,
        keyboardType: TextInputType.number,
        style: TextStyle(color: _themeColor.mainForeColor, fontWeight: FontWeight.bold, fontSize: 14),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        onFieldSubmitted: (value) {
          double? newValue = double.tryParse(value);
          if (newValue != null) {
            setState(() {
              _frequency = newValue.clamp(20.0, 20000.0);
              _currentBaseFreq = _frequency / pow(2, _octave);
              _freqController.text = _frequency.toStringAsFixed(2);
            });
          }
        },
      ),
    );
  }

  Widget _buildWaveTypeSelector() {
    final ColorScheme t = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: DropdownButton<String>(
        value: _waveType,
        isExpanded: true,
        dropdownColor: _themeColor.mainDropdownColor,
        style: TextStyle(color: t.primary, fontSize: 18),
        items: ['Sine', 'Square', 'Sawtooth', 'Triangle']
            .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setState(() => _waveType = v!),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: _themeColor.mainForeColor)),
            Text(value.toStringAsFixed(2), style: TextStyle(color: _themeColor.mainForeColor, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged, label: value.toStringAsFixed(2)),
      ],
    );
  }

  Widget _buildPlayButton() {
    final ColorScheme t = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: _isPlaying ? null : _togglePlay,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _isPlaying ? t.secondary : t.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text("PLAY",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isPlaying ? _themeColor.mainForeColor : _themeColor.mainButtonForeColor
                  )
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: !_isPlaying ? null : _togglePlay,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: !_isPlaying ? t.secondary : t.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text("STOP",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: !_isPlaying ? _themeColor.mainForeColor : _themeColor.mainButtonForeColor
                  )
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
