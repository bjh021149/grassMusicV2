import 'package:flutter/material.dart';

/*
  void _updateLyrics(RawLyricResponse lyricData) {
    _lyric = {
      'lyric': lyricData.lrc,
      'translatedLyric': lyricData.tlyric,
      'klyric': lyricData.klyric,
      'yrc': lyricData.yrc,
      'romalrc': lyricData.romalrc,
    };
    _processedLyric = lyricData.hasLrc ? lyricData.lrc.parsedLyrics() : {};
    _processedTranslatedLyric =
        lyricData.hasTranslation ? lyricData.tlyric.parsedLyrics() : {};
    _processedYrcLyric =
        lyricData.hasWordByWord
            ? lyricData.yrc.convertYrcLines().parsedLyrics()
            : {};
    _lyricStateNotifier();
    notifyListeners();

    //print(lyricData.yrc.convertYrcLines().parsedLyrics()['lyrics']);
    //int(lyricData.lrc.parsedLyrics()['lyrics']);
  }

  Future<void> _getSongLyric(String id) async {
    _lyricData = await _api.getLyricNew([id]);
    _updateLyrics(lyricData);
  }
*/
class MiniLyricsWidget extends StatefulWidget {
  final String lyrics; // 歌词内容
  final Duration position; // 当前时间位置
  final Duration duration; // 歌曲总时长
  final bool isLyricChanged;

  const MiniLyricsWidget({
    super.key,
    required this.lyrics,
    required this.position,
    required this.duration,
    required this.isLyricChanged,
  });

  @override
  State<MiniLyricsWidget> createState() => _LyricsWidgetState();
}

class _LyricsWidgetState extends State<MiniLyricsWidget> {
  String previousLine = '';
  String currentLine = '';
  String nextLine = '';
  String cachedLyrics = '';
  List<String> lines = [];
  int currentIndex = -1;
  late Size size;
  @override
  void didUpdateWidget(MiniLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isLyricChanged && widget.lyrics.isNotEmpty) {
      cachedLyrics = widget.lyrics;
      lines = cachedLyrics.split('\n');

      setState(() {
        _updateLinesContext();
      });
    }
    // 当 position 或 lyrics 发生变化时，更新歌词上下文
    if (oldWidget.position != widget.position ||
        widget.position.inMilliseconds == 0) {
      _updateLinesContext();
    }
  }

  @override
  void initState() {
    super.initState();
    _updateLinesContext();
  }

  /// 更新歌词上下文，仅在匹配到新的高亮歌词时更新
  void _updateLinesContext() {
    if (lines.isEmpty) return;

    final line = lines[0];
    final match = RegExp(r'^\[(\d+),(\d+)\]').firstMatch(line);
    if (match != null) {
      final start = int.parse(match.group(1)!);
      if (widget.position.inMilliseconds < start && currentIndex == -1) {
        setState(() {
          currentLine = lines.first;
        });
        return;
      }
    }
    // Find the current line
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = RegExp(r'^\[(\d+),(\d+)\]').firstMatch(line);
      if (match != null) {
        final start = int.parse(match.group(1)!);
        final duration = int.parse(match.group(2)!);
        final end = start + duration;

        if (widget.position.inMilliseconds >= start &&
            widget.position.inMilliseconds <= end) {
          setState(() {
            currentLine = line;

            currentIndex = i;
          });
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HighlightedLyricsLine(line: currentLine, currentTime: widget.position),
      ],
    );
  }
}

// 通用样式
const TextStyle defaultTextStyle = TextStyle(
  fontSize: 24,
  color: Colors.grey,
  fontFamily: 'SmileySans',
);
const TextStyle highlightedTextStyle = TextStyle(
  fontSize: 24,
  color: Colors.red,
  fontFamily: 'SmileySans',
);

class HighlightedLyricsLine extends StatelessWidget {
  final String line;
  final Duration currentTime;

  const HighlightedLyricsLine({
    super.key,
    required this.line,
    required this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(MediaQuery.of(context).size.width, 50), // 固定高度
      painter: HighlightedLinePainter(line, currentTime),
    );
  }
}

class HighlightedLinePainter extends CustomPainter {
  final String line;
  final Duration currentTime;
  final double wordSpacing;

  String? _lastLine; // Cache the last line content to detect changes

  HighlightedLinePainter(this.line, this.currentTime, {this.wordSpacing = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    // Check if the line content has changed; if not, reuse the cached picture
    if (_lastLine == line) {
      _drawHighlight(canvas, size);
    } else {
      _lastLine = line;
      _drawDefaultStyle(canvas, size);
      _drawHighlight(canvas, size);
    }
    // Draw the highlighted part of the line
  }

  void _drawDefaultStyle(Canvas canvas, Size size) {
    final lineMatch = RegExp(r'^\[(\d+),(\d+)\](.*)').firstMatch(line);
    if (lineMatch == null) return;

    final content = lineMatch.group(3)!;

    final words =
        RegExp(r'([^\s\(]+)\((\d+),(\d+)\)').allMatches(content).map((match) {
          return {
            'text': match.group(1)!,
            'start': int.parse(match.group(2)!),
            'end': int.parse(match.group(2)!) + int.parse(match.group(3)!),
          };
        }).toList();

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    double totalWidth = 0;

    for (var word in words) {
      textPainter.text = TextSpan(
        text: '${word['text']} ',
        style: TextStyle(
          fontSize: 24,
          color: Colors.grey,
          fontFamily: 'SmileySans',
        ),
      );
      textPainter.layout();
      totalWidth += textPainter.width + wordSpacing;
    }

    totalWidth -= wordSpacing;

    double xOffset = (size.width / 2) - (totalWidth / 2);

    for (var word in words) {
      textPainter.text = TextSpan(
        text: '${word['text']} ',
        style: TextStyle(
          fontSize: 24,
          color: Colors.red,
          fontFamily: 'SmileySans',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(xOffset, 0));
      xOffset += textPainter.width + wordSpacing;
    }
  }

  void _drawHighlight(Canvas canvas, Size size) {
    final lineMatch = RegExp(r'^\[(\d+),(\d+)\](.*)').firstMatch(line);
    if (lineMatch == null) return;

    final start = int.parse(lineMatch.group(1)!);
    final duration = int.parse(lineMatch.group(2)!);
    final end = start + duration;
    final content = lineMatch.group(3)!;

    if (!(currentTime.inMilliseconds >= start &&
        currentTime.inMilliseconds <= end)) {
      return;
    }

    final words =
        RegExp(r'([^\s\(]+)\((\d+),(\d+)\)').allMatches(content).map((match) {
          return {
            'text': match.group(1)!,
            'start': int.parse(match.group(2)!),
            'end': int.parse(match.group(2)!) + int.parse(match.group(3)!),
          };
        }).toList();

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    double totalWidth = 0;

    for (var word in words) {
      textPainter.text = TextSpan(
        text: '${word['text']} ',
        style: defaultTextStyle,
      );
      textPainter.layout();
      totalWidth += textPainter.width + wordSpacing;
    }

    totalWidth -= wordSpacing;

    double xOffset = (size.width / 2) - (totalWidth / 2);

    for (var word in words) {
      final wordStart = word['start']! as int;
      final wordEnd = word['end']! as int;

      double progress = 0;
      if (currentTime.inMilliseconds >= wordStart &&
          currentTime.inMilliseconds < wordEnd) {
        progress =
            (currentTime.inMilliseconds - wordStart) / (wordEnd - wordStart);
      } else if (currentTime.inMilliseconds >= wordEnd) {
        progress = 1;
      }

      // Draw default style
      textPainter.text = TextSpan(
        text: '${word['text']} ',
        style: defaultTextStyle,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(xOffset, 0));

      // Draw highlight if progress > 0
      if (progress > 0) {
        final clipWidth = textPainter.width * progress;
        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH(xOffset, 0, clipWidth, textPainter.height),
        );
        textPainter.text = TextSpan(
          text: '${word['text']} ',
          style: highlightedTextStyle,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(xOffset, 0));
        canvas.restore();
      }

      xOffset += textPainter.width + wordSpacing;
    }
  }

  @override
  @override
  bool shouldRepaint(covariant HighlightedLinePainter oldDelegate) {
    return oldDelegate.line != line || oldDelegate.currentTime != currentTime;
  }
}
