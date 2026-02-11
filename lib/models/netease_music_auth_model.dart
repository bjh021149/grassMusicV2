import 'package:json_annotation/json_annotation.dart';

part 'netease_music_auth_model.g.dart';

@JsonSerializable()
class LoginResult {
  final int loginType;

  final String clientId;

  final int effectTime;

  final int code;

  final Account account;

  final String token;

  final Profile profile;

  final List<Binding> bindings;

  final String cookie;

  LoginResult({
    required this.loginType,
    required this.clientId,
    required this.effectTime,
    required this.code,
    required this.account,
    required this.token,
    required this.profile,
    required this.bindings,
    required this.cookie,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) =>
      _$LoginResultFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResultToJson(this);
}

@JsonSerializable()
class Account {
  final int id;
  final String userName;
  final int type;
  final int status;
  final int whitelistAuthority;
  final int createTime;
  final String salt;
  final int tokenVersion;
  final int ban;
  final int baoyueVersion;
  final int donateVersion;
  final int vipType;
  final int viptypeVersion;
  final bool anonimousUser;
  final bool uninitialized;

  Account({
    required this.id,
    required this.userName,
    required this.type,
    required this.status,
    required this.whitelistAuthority,
    required this.createTime,
    required this.salt,
    required this.tokenVersion,
    required this.ban,
    required this.baoyueVersion,
    required this.donateVersion,
    required this.vipType,
    required this.viptypeVersion,
    required this.anonimousUser,
    required this.uninitialized,
  });

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);

  Map<String, dynamic> toJson() => _$AccountToJson(this);
}

@JsonSerializable()
class Profile {
  final int userType;
  final String avatarUrl;
  final int vipType;
  final int authStatus;
  final int djStatus;
  final String detailDescription;
  final Map<String, dynamic> experts;
  final dynamic expertTags;
  final int accountStatus;
  final String nickname;
  final int birthday;
  final int gender;
  final int province;
  final int city;
  final int avatarImgId;
  final int backgroundImgId;
  final bool defaultAvatar;
  final bool mutual;
  final dynamic remarkName;
  final bool followed;
  final String backgroundUrl;
  final String avatarImgIdStr;
  final String backgroundImgIdStr;
  final String description;
  final int userId;
  final String signature;
  final int authority;
  final int followeds;
  final int follows;
  final int eventCount;
  final dynamic avatarDetail;
  final int playlistCount;
  final int playlistBeSubscribedCount;

  Profile({
    required this.userType,
    required this.avatarUrl,
    required this.vipType,
    required this.authStatus,
    required this.djStatus,
    required this.detailDescription,
    required this.experts,
    required this.expertTags,
    required this.accountStatus,
    required this.nickname,
    required this.birthday,
    required this.gender,
    required this.province,
    required this.city,
    required this.avatarImgId,
    required this.backgroundImgId,
    required this.defaultAvatar,
    required this.mutual,
    required this.remarkName,
    required this.followed,
    required this.backgroundUrl,
    required this.avatarImgIdStr,
    required this.backgroundImgIdStr,
    required this.description,
    required this.userId,
    required this.signature,
    required this.authority,
    required this.followeds,
    required this.follows,
    required this.eventCount,
    required this.avatarDetail,
    required this.playlistCount,
    required this.playlistBeSubscribedCount,
  });

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileToJson(this);
}

@JsonSerializable()
class Binding {
  final int bindingTime;
  final int refreshTime;
  final Map<String, dynamic> tokenJsonStr;
  final int expiresIn;
  final String url;
  final bool expired;
  final int userId;
  final int id;
  final int type;

  Binding({
    required this.bindingTime,
    required this.refreshTime,
    required this.tokenJsonStr,
    required this.expiresIn,
    required this.url,
    required this.expired,
    required this.userId,
    required this.id,
    required this.type,
  });

  factory Binding.fromJson(Map<String, dynamic> json) =>
      _$BindingFromJson(json);

  Map<String, dynamic> toJson() => _$BindingToJson(this);
}
