// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'netease_music_auth_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginResult _$LoginResultFromJson(Map<String, dynamic> json) => LoginResult(
  loginType: (json['loginType'] as num).toInt(),
  clientId: json['clientId'] as String,
  effectTime: (json['effectTime'] as num).toInt(),
  code: (json['code'] as num).toInt(),
  account: Account.fromJson(json['account'] as Map<String, dynamic>),
  token: json['token'] as String,
  profile: Profile.fromJson(json['profile'] as Map<String, dynamic>),
  bindings:
      (json['bindings'] as List<dynamic>)
          .map((e) => Binding.fromJson(e as Map<String, dynamic>))
          .toList(),
  cookie: json['cookie'] as String,
);

Map<String, dynamic> _$LoginResultToJson(LoginResult instance) =>
    <String, dynamic>{
      'loginType': instance.loginType,
      'clientId': instance.clientId,
      'effectTime': instance.effectTime,
      'code': instance.code,
      'account': instance.account,
      'token': instance.token,
      'profile': instance.profile,
      'bindings': instance.bindings,
      'cookie': instance.cookie,
    };

Account _$AccountFromJson(Map<String, dynamic> json) => Account(
  id: (json['id'] as num).toInt(),
  userName: json['userName'] as String,
  type: (json['type'] as num).toInt(),
  status: (json['status'] as num).toInt(),
  whitelistAuthority: (json['whitelistAuthority'] as num).toInt(),
  createTime: (json['createTime'] as num).toInt(),
  salt: json['salt'] as String,
  tokenVersion: (json['tokenVersion'] as num).toInt(),
  ban: (json['ban'] as num).toInt(),
  baoyueVersion: (json['baoyueVersion'] as num).toInt(),
  donateVersion: (json['donateVersion'] as num).toInt(),
  vipType: (json['vipType'] as num).toInt(),
  viptypeVersion: (json['viptypeVersion'] as num).toInt(),
  anonimousUser: json['anonimousUser'] as bool,
  uninitialized: json['uninitialized'] as bool,
);

Map<String, dynamic> _$AccountToJson(Account instance) => <String, dynamic>{
  'id': instance.id,
  'userName': instance.userName,
  'type': instance.type,
  'status': instance.status,
  'whitelistAuthority': instance.whitelistAuthority,
  'createTime': instance.createTime,
  'salt': instance.salt,
  'tokenVersion': instance.tokenVersion,
  'ban': instance.ban,
  'baoyueVersion': instance.baoyueVersion,
  'donateVersion': instance.donateVersion,
  'vipType': instance.vipType,
  'viptypeVersion': instance.viptypeVersion,
  'anonimousUser': instance.anonimousUser,
  'uninitialized': instance.uninitialized,
};

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
  userType: (json['userType'] as num).toInt(),
  avatarUrl: json['avatarUrl'] as String,
  vipType: (json['vipType'] as num).toInt(),
  authStatus: (json['authStatus'] as num).toInt(),
  djStatus: (json['djStatus'] as num).toInt(),
  detailDescription: json['detailDescription'] as String,
  experts: json['experts'] as Map<String, dynamic>,
  expertTags: json['expertTags'],
  accountStatus: (json['accountStatus'] as num).toInt(),
  nickname: json['nickname'] as String,
  birthday: (json['birthday'] as num).toInt(),
  gender: (json['gender'] as num).toInt(),
  province: (json['province'] as num).toInt(),
  city: (json['city'] as num).toInt(),
  avatarImgId: (json['avatarImgId'] as num).toInt(),
  backgroundImgId: (json['backgroundImgId'] as num).toInt(),
  defaultAvatar: json['defaultAvatar'] as bool,
  mutual: json['mutual'] as bool,
  remarkName: json['remarkName'],
  followed: json['followed'] as bool,
  backgroundUrl: json['backgroundUrl'] as String,
  avatarImgIdStr: json['avatarImgIdStr'] as String,
  backgroundImgIdStr: json['backgroundImgIdStr'] as String,
  description: json['description'] as String,
  userId: (json['userId'] as num).toInt(),
  signature: json['signature'] as String,
  authority: (json['authority'] as num).toInt(),
  followeds: (json['followeds'] as num).toInt(),
  follows: (json['follows'] as num).toInt(),
  eventCount: (json['eventCount'] as num).toInt(),
  avatarDetail: json['avatarDetail'],
  playlistCount: (json['playlistCount'] as num).toInt(),
  playlistBeSubscribedCount: (json['playlistBeSubscribedCount'] as num).toInt(),
);

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
  'userType': instance.userType,
  'avatarUrl': instance.avatarUrl,
  'vipType': instance.vipType,
  'authStatus': instance.authStatus,
  'djStatus': instance.djStatus,
  'detailDescription': instance.detailDescription,
  'experts': instance.experts,
  'expertTags': instance.expertTags,
  'accountStatus': instance.accountStatus,
  'nickname': instance.nickname,
  'birthday': instance.birthday,
  'gender': instance.gender,
  'province': instance.province,
  'city': instance.city,
  'avatarImgId': instance.avatarImgId,
  'backgroundImgId': instance.backgroundImgId,
  'defaultAvatar': instance.defaultAvatar,
  'mutual': instance.mutual,
  'remarkName': instance.remarkName,
  'followed': instance.followed,
  'backgroundUrl': instance.backgroundUrl,
  'avatarImgIdStr': instance.avatarImgIdStr,
  'backgroundImgIdStr': instance.backgroundImgIdStr,
  'description': instance.description,
  'userId': instance.userId,
  'signature': instance.signature,
  'authority': instance.authority,
  'followeds': instance.followeds,
  'follows': instance.follows,
  'eventCount': instance.eventCount,
  'avatarDetail': instance.avatarDetail,
  'playlistCount': instance.playlistCount,
  'playlistBeSubscribedCount': instance.playlistBeSubscribedCount,
};

Binding _$BindingFromJson(Map<String, dynamic> json) => Binding(
  bindingTime: (json['bindingTime'] as num).toInt(),
  refreshTime: (json['refreshTime'] as num).toInt(),
  tokenJsonStr: json['tokenJsonStr'] as Map<String, dynamic>,
  expiresIn: (json['expiresIn'] as num).toInt(),
  url: json['url'] as String,
  expired: json['expired'] as bool,
  userId: (json['userId'] as num).toInt(),
  id: (json['id'] as num).toInt(),
  type: (json['type'] as num).toInt(),
);

Map<String, dynamic> _$BindingToJson(Binding instance) => <String, dynamic>{
  'bindingTime': instance.bindingTime,
  'refreshTime': instance.refreshTime,
  'tokenJsonStr': instance.tokenJsonStr,
  'expiresIn': instance.expiresIn,
  'url': instance.url,
  'expired': instance.expired,
  'userId': instance.userId,
  'id': instance.id,
  'type': instance.type,
};
