import 'package:flutter/material.dart';
import 'package:flutter_chatgpt/core/rebuild.dart';
import 'package:flutter_chatgpt/data/res/ui.dart';
import 'package:logging/logging.dart';

const _kMaxDebugLogLines = 177;
const _level2Color = {
  'INFO': Colors.blue,
  'WARNING': Colors.yellow,
};

abstract final class DebugNotifier {
  static final node = RebuildNode();
  static final state = <Widget>[];

  static void addLog(LogRecord record) {
    final color = _level2Color[record.level.name] ?? Colors.blue;
    state.addAll([
      Text.rich(TextSpan(
        children: [
          TextSpan(
            text: '[${record.loggerName}]',
            style: const TextStyle(color: Colors.cyan),
          ),
          TextSpan(
            text: '[${record.level}]',
            style: TextStyle(color: color),
          ),
          TextSpan(
            text: record.error == null
                ? '\n${record.message}'
                : '\n${record.message}: ${record.error}',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      )),
      if (record.stackTrace != null)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            '${record.stackTrace}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      UIs.height13,
    ]);

    if (state.length > _kMaxDebugLogLines) {
      state.sublist(state.length - _kMaxDebugLogLines);
    }
    
    node.rebuild();
  }
}
