import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:gpt_box/core/ext/file.dart';
import 'package:gpt_box/data/res/l10n.dart';
import 'package:gpt_box/data/res/url.dart';
import 'package:gpt_box/data/store/all.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:shortid/shortid.dart';

part 'history.g.dart';

@HiveType(typeId: 5)
@JsonSerializable()
final class ChatHistory {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final List<ChatHistoryItem> items;
  @HiveField(2)
  @JsonKey(includeIfNull: false)
  final String? name;
  // Fields with id 3/4/5 are deleted
  @HiveField(6)
  @JsonKey(includeIfNull: false)
  final ChatSettings? settings;

  ChatHistory({
    required this.items,
    required this.id,
    this.name,
    this.settings,
  });

  ChatHistory.noid({
    required this.items,
    this.name,
    this.settings,
  }) : id = shortid.generate();

  static ChatHistory get empty => ChatHistory.noid(items: []);

  String get toMarkdown {
    final sb = StringBuffer();
    for (final item in items) {
      sb.writeln(item.role.localized);
      sb.writeln(item.toMarkdown);
    }
    return sb.toString();
  }

  static ChatHistory get example => ChatHistory.noid(
        name: l10n.help,
        items: [
          ChatHistoryItem.single(
            role: ChatRole.system,
            type: ChatContentType.text,
            raw: l10n.initChatHelp(Urls.repoIssue, Urls.unilinkDoc),
          ),
        ],
      );

  bool get isInitHelp =>
      name == l10n.help &&
      items.length == 1 &&
      items.first.role.isSystem &&
      items.first.content.length == 1 &&
      items.first.content.first.raw.contains(Urls.repoIssue);

  ChatHistory copyWith({
    List<ChatHistoryItem>? items,
    String? name,
    ChatSettings? settings,
  }) {
    return ChatHistory(
      id: id,
      items: items ?? this.items,
      name: name ?? this.name,
      settings: settings ?? this.settings,
    );
  }

  void save() {
    Stores.history.put(this);
  }

  bool containsKeywords(List<String> keywords) {
    return items.any(
      (e) => e.content.any(
        (e) => keywords.any((e) => e.contains(e)),
      ),
    );
  }

  factory ChatHistory.fromJson(Map<String, dynamic> json) =>
      _$ChatHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$ChatHistoryToJson(this);
}

typedef OaiHistoryItem = ChatCompletionMessage;

@HiveType(typeId: 0)
@JsonSerializable()
final class ChatHistoryItem {
  @HiveField(0)
  final ChatRole role;
  @HiveField(1)
  final List<ChatContent> content;
  @HiveField(2)
  final DateTime createdAt;
  @HiveField(3)
  final String id;
  @HiveField(4)
  @JsonKey(includeIfNull: false)
  final String? toolCallId;

  const ChatHistoryItem({
    required this.role,
    required this.content,
    required this.createdAt,
    required this.id,
    this.toolCallId,
  });

  ChatHistoryItem.gen({
    required this.role,
    required this.content,
    this.toolCallId,
  })  : createdAt = DateTime.now(),
        id = shortid.generate();

  ChatHistoryItem.single({
    required this.role,
    String raw = '',
    ChatContentType type = ChatContentType.text,
    DateTime? createdAt,
    this.toolCallId,
  })  : content = [ChatContent.noid(type: type, raw: raw)],
        createdAt = createdAt ?? DateTime.now(),
        id = shortid.generate();

  String get toMarkdown {
    return content
        .map((e) => switch (e.type) {
              ChatContentType.text => e.raw,
              ChatContentType.image => '![$id](${e.raw})',
              ChatContentType.audio => '[$id](${e.raw})',
            })
        .join('\n');
  }

  ChatHistoryItem copyWith({
    ChatRole? role,
    List<ChatContent>? content,
    DateTime? createdAt,
    @protected String? id,
    String? toolCallId,
  }) {
    return ChatHistoryItem(
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      id: id ?? this.id,
      toolCallId: toolCallId ?? this.toolCallId,
    );
  }

  /// - If [asStr], return [ChatCompletionMessage] with [String] content.
  /// It's for deepseek's api compatibility.
  OaiHistoryItem toOpenAI({bool asStr = true}) {
    switch (role) {
      case ChatRole.user:
        final hasImg = content.any((e) => e.isImg);
        return ChatCompletionMessage.user(
          content: asStr && !hasImg
              ? ChatCompletionUserMessageContent.string(
                  content.map((e) => e.raw).join('\n'))
              : ChatCompletionUserMessageContent.parts(
                  content.map((e) => e.toOpenAI).toList()),
        );
      case ChatRole.assist:
        return ChatCompletionMessage.assistant(
          content: content.map((e) => e.raw).join('\n'),
        );
      case ChatRole.system:
        return ChatCompletionMessage.system(
          content: content.map((e) => e.raw).join('\n'),
        );
      case ChatRole.tool:
        return ChatCompletionMessage.tool(
          toolCallId: toolCallId!,
          content: content.map((e) => e.raw).join('\n'),
        );
    }
  }

  Future<OaiHistoryItem> toApi({bool asStr = true}) async {
    final contents = await Future.wait(content.map((e) => e.toApi));
    return copyWith(content: contents).toOpenAI(asStr: asStr);
  }

  factory ChatHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$ChatHistoryItemFromJson(json);

  Map<String, dynamic> toJson() => _$ChatHistoryItemToJson(this);
}

/// Handle [audio] and [image] as url (/path & https://) or base64
@HiveType(typeId: 1)
@JsonEnum()
enum ChatContentType {
  @HiveField(0)
  text,
  @HiveField(1)
  audio,
  @HiveField(2)
  image,
  ;
}

typedef OaiContent = ChatCompletionMessageContentPart;

@HiveType(typeId: 2)
@JsonSerializable()
final class ChatContent {
  @HiveField(0)
  final ChatContentType type;
  @HiveField(1)
  String raw;
  @HiveField(2, defaultValue: '')
  final String id;

  ChatContent({
    required this.type,
    required this.raw,
    required String id,
  }) : id = id.isEmpty ? shortid.generate() : id;
  ChatContent.noid({required this.type, required this.raw})
      : id = shortid.generate();
  ChatContent.text(this.raw)
      : type = ChatContentType.text,
        id = shortid.generate();
  ChatContent.audio(this.raw)
      : type = ChatContentType.audio,
        id = shortid.generate();
  ChatContent.image(this.raw)
      : type = ChatContentType.image,
        id = shortid.generate();

  bool get isText => type == ChatContentType.text;
  bool get isImg => type == ChatContentType.image;
  bool get isAudio => type == ChatContentType.audio;

  OaiContent get toOpenAI => switch (type) {
        ChatContentType.text => OaiContent.text(text: raw),
        ChatContentType.image =>
          OaiContent.image(imageUrl: ChatCompletionMessageImageUrl(url: raw)),
        _ => throw UnimplementedError('$type.toOpenAI'),
      };

  ChatContent copyWith({
    ChatContentType? type,
    String? raw,
    String? id,
  }) {
    return ChatContent(
      type: type ?? this.type,
      raw: raw ?? this.raw,
      id: id ?? this.id,
    );
  }

  /// {@template img_url_to_api}
  /// Convert local file to base64
  /// {@endtemplate}
  Future<ChatContent> get toApi async {
    if (!isImg) return this;
    return copyWith(raw: await ChatContent.contentToApi(raw));
  }

  /// {@macro img_url_to_api}
  ///
  /// Seperate from [toApi] to decouple the logic
  static Future<String> contentToApi(String raw) async {
    final isLocal = raw.isFileUrl(false);
    if (isLocal) {
      final file = File(raw);
      final b64 = await file.base64;
      if (b64 != null) raw = b64;
    }
    return raw;
  }

  void deleteFile() async {
    if (isText) return;
    final isLocal = raw.isFileUrl(false);
    if (isLocal) {
      final file = File(raw);
      await file.delete();
    } else {
      await FileApi.delete([raw]);
    }
  }

  factory ChatContent.fromJson(Map<String, dynamic> json) =>
      _$ChatContentFromJson(json);

  Map<String, dynamic> toJson() => _$ChatContentToJson(this);
}

@HiveType(typeId: 3)
@JsonEnum()
enum ChatRole {
  @HiveField(0)
  user,
  @HiveField(1)
  assist,
  @HiveField(2)
  system,
  @HiveField(3)
  tool,
  ;

  bool get isUser => this == user;
  bool get isAssist => this == assist;
  bool get isSystem => this == system;
  bool get isTool => this == tool;

  String get localized => switch (this) {
        user => Stores.setting.avatar.fetch(),
        assist => '🤖',
        system => '⚙️',
        tool => '🛠️',
      };

  Color get color {
    final c = switch (this) {
      user => UIs.primaryColor,
      assist => UIs.primaryColor.withBlue(233),
      system => UIs.primaryColor.withRed(233),
      tool => UIs.primaryColor.withBlue(33),
    };
    return c.withOpacity(0.5);
  }

  static ChatRole? fromString(String? val) => switch (val) {
        'assistant' => assist,
        _ => values.firstWhereOrNull((p0) => p0.name == val),
      };
}

@HiveType(typeId: 8)
@JsonSerializable()
final class ChatSettings {
  @HiveField(0)
  @JsonKey(name: 'htm')
  final bool headTailMode;
  @HiveField(1)
  @JsonKey(name: 'ut')
  final bool useTools;
  @HiveField(2)
  @JsonKey(name: 'icc')
  final bool ignoreContextConstraint;

  /// Use this constrctor pattern to avoid null value as the [ChatSettings]'s
  /// properties are changing frequently.
  const ChatSettings({
    bool? headTailMode,
    bool? useTools,
    bool? ignoreContextConstraint,
  })  : headTailMode = headTailMode ?? false,
        useTools = useTools ?? true,
        ignoreContextConstraint = ignoreContextConstraint ?? false;

  ChatSettings copyWith({
    bool? headTailMode,
    bool? useTools,
    bool? ignoreContextConstraint,
  }) {
    return ChatSettings(
      headTailMode: headTailMode ?? this.headTailMode,
      useTools: useTools ?? this.useTools,
      ignoreContextConstraint:
          ignoreContextConstraint ?? this.ignoreContextConstraint,
    );
  }

  @override
  String toString() => 'ChatSettings${toJson()}';

  factory ChatSettings.fromJson(Map<String, dynamic> json) =>
      _$ChatSettingsFromJson(json);
  
  Map<String, dynamic> toJson() => _$ChatSettingsToJson(this);
}
